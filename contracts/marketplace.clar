;; Marketplace Contract - Seed Trading Platform
;; Trading functionality, escrow services, and market operations

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_LISTING (err u201))
(define-constant ERR_LISTING_NOT_FOUND (err u202))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u203))
(define-constant ERR_LISTING_EXPIRED (err u204))
(define-constant ERR_INVALID_QUANTITY (err u205))
(define-constant ERR_LISTING_NOT_ACTIVE (err u206))
(define-constant ERR_SELLER_CANNOT_BUY (err u207))
(define-constant ERR_INSUFFICIENT_SEEDS (err u208))
(define-constant ERR_DISPUTE_EXPIRED (err u209))

;; Listing Status
(define-constant STATUS_ACTIVE u0)
(define-constant STATUS_SOLD u1)
(define-constant STATUS_CANCELLED u2)
(define-constant STATUS_DISPUTED u3)
(define-constant STATUS_EXPIRED u4)

;; Order Status
(define-constant ORDER_PENDING u0)
(define-constant ORDER_CONFIRMED u1)
(define-constant ORDER_SHIPPED u2)
(define-constant ORDER_DELIVERED u3)
(define-constant ORDER_DISPUTED u4)
(define-constant ORDER_COMPLETED u5)

;; Configuration Constants
(define-constant MARKETPLACE_FEE_RATE u250) ;; 2.5% marketplace fee (250/10000)
(define-constant MIN_PRICE u1) ;; Minimum price per seed (1 microSTX)
(define-constant MAX_PRICE u1000000) ;; Maximum price per seed (1 STX)
(define-constant MAX_LISTING_DURATION u8760) ;; Max 1 year (365 * 24 hours)
(define-constant MIN_LISTING_DURATION u1) ;; Min 1 hour
(define-constant ESCROW_PERIOD u168) ;; 7 days in hours
(define-constant DISPUTE_PERIOD u72) ;; 3 days dispute window

;; Data Variables
(define-data-var next-listing-id uint u1)
(define-data-var next-order-id uint u1)
(define-data-var total-listings uint u0)
(define-data-var total-sales uint u0)
(define-data-var total-volume uint u0)
(define-data-var marketplace-paused bool false)

;; Data Maps
(define-map listings
    uint ;; listing-id
    {
        batch-id: uint,
        seller: principal,
        quantity: uint,
        price-per-seed: uint, ;; in microSTX
        total-price: uint,
        description: (string-ascii 500),
        created-at: uint,
        expires-at: uint,
        status: uint,
        quality-guarantee: bool,
        shipping-regions: (list 10 (string-ascii 50)),
        sold-quantity: uint
    }
)

(define-map orders
    uint ;; order-id
    {
        listing-id: uint,
        buyer: principal,
        seller: principal,
        quantity: uint,
        total-amount: uint,
        marketplace-fee: uint,
        seller-amount: uint,
        shipping-address: (string-ascii 300),
        created-at: uint,
        status: uint,
        tracking-info: (optional (string-ascii 200)),
        delivery-confirmed: bool
    }
)

(define-map escrow-funds
    uint ;; order-id
    {
        amount: uint,
        deposited-at: uint,
        released: bool,
        dispute-deadline: uint
    }
)

(define-map seller-listings
    principal ;; seller address
    (list 100 uint) ;; list of listing IDs
)

(define-map buyer-orders
    principal ;; buyer address
    (list 100 uint) ;; list of order IDs
)

(define-map marketplace-stats
    principal ;; user address
    {
        total-bought: uint,
        total-sold: uint,
        reputation-score: uint, ;; 0-100
        successful-transactions: uint,
        disputed-transactions: uint
    }
)

(define-map disputes
    uint ;; order-id
    {
        disputer: principal,
        reason: (string-ascii 500),
        created-at: uint,
        resolved: bool,
        resolution: (optional (string-ascii 500)),
        resolver: (optional principal)
    }
)

;; Private Functions

(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (calculate-marketplace-fee (amount uint))
    (/ (* amount MARKETPLACE_FEE_RATE) u10000)
)

(define-private (is-valid-price (price uint))
    (and (>= price MIN_PRICE) (<= price MAX_PRICE))
)

(define-private (is-valid-duration (duration uint))
    (and (>= duration MIN_LISTING_DURATION) (<= duration MAX_LISTING_DURATION))
)

(define-private (update-seller-listings (seller principal) (listing-id uint))
    (let ((current-listings (default-to (list) (map-get? seller-listings seller))))
        (begin
            (map-set seller-listings seller (unwrap! (as-max-len? (append current-listings listing-id) u100) (err u999)))
            (ok true)
        )
    )
)

(define-private (update-buyer-orders (buyer principal) (order-id uint))
    (let ((current-orders (default-to (list) (map-get? buyer-orders buyer))))
        (begin
            (map-set buyer-orders buyer (unwrap! (as-max-len? (append current-orders order-id) u100) (err u998)))
            (ok true)
        )
    )
)

(define-private (update-user-stats (user principal) (amount uint) (is-seller bool))
    (let ((current-stats (default-to {
            total-bought: u0,
            total-sold: u0,
            reputation-score: u50,
            successful-transactions: u0,
            disputed-transactions: u0
        } (map-get? marketplace-stats user))))
        (begin
            (map-set marketplace-stats user {
                total-bought: (if is-seller (get total-bought current-stats) (+ (get total-bought current-stats) amount)),
                total-sold: (if is-seller (+ (get total-sold current-stats) amount) (get total-sold current-stats)),
                reputation-score: (get reputation-score current-stats),
                successful-transactions: (+ (get successful-transactions current-stats) u1),
                disputed-transactions: (get disputed-transactions current-stats)
            })
            (ok true)
        )
    )
)

;; Public Functions

;; List seeds for sale
(define-public (list-seeds (batch-id uint) (quantity uint) (price-per-seed uint) (duration-hours uint) (description (string-ascii 500)) (quality-guarantee bool) (shipping-regions (list 10 (string-ascii 50))))
    (let (
        (listing-id (var-get next-listing-id))
        (current-time stacks-block-height)
        (expires-at (+ current-time duration-hours))
        (total-price (* quantity price-per-seed))
    )
        ;; Validation checks
        (asserts! (not (var-get marketplace-paused)) (err u210))
        (asserts! (> quantity u0) ERR_INVALID_QUANTITY)
        (asserts! (is-valid-price price-per-seed) ERR_INVALID_LISTING)
        (asserts! (is-valid-duration duration-hours) ERR_INVALID_LISTING)
        (asserts! (> (len description) u0) ERR_INVALID_LISTING)
        
        ;; Note: In a real implementation, we would verify batch ownership and availability
        ;; through the seed-registry contract, but avoiding cross-contract calls per requirements
        
        ;; Create the listing
        (map-set listings listing-id {
            batch-id: batch-id,
            seller: tx-sender,
            quantity: quantity,
            price-per-seed: price-per-seed,
            total-price: total-price,
            description: description,
            created-at: current-time,
            expires-at: expires-at,
            status: STATUS_ACTIVE,
            quality-guarantee: quality-guarantee,
            shipping-regions: shipping-regions,
            sold-quantity: u0
        })
        
        ;; Update tracking
        (unwrap! (update-seller-listings tx-sender listing-id) (err u997))
        
        ;; Update counters
        (var-set next-listing-id (+ listing-id u1))
        (var-set total-listings (+ (var-get total-listings) u1))
        
        (ok listing-id)
    )
)

;; Purchase seeds
(define-public (purchase-seeds (listing-id uint) (quantity uint) (shipping-address (string-ascii 300)))
    (let (
        (listing (unwrap! (map-get? listings listing-id) ERR_LISTING_NOT_FOUND))
        (order-id (var-get next-order-id))
        (available-quantity (- (get quantity listing) (get sold-quantity listing)))
        (total-amount (* quantity (get price-per-seed listing)))
        (marketplace-fee (calculate-marketplace-fee total-amount))
        (seller-amount (- total-amount marketplace-fee))
        (current-time stacks-block-height)
    )
        ;; Validation checks
        (asserts! (not (var-get marketplace-paused)) (err u210))
        (asserts! (is-eq (get status listing) STATUS_ACTIVE) ERR_LISTING_NOT_ACTIVE)
        (asserts! (< current-time (get expires-at listing)) ERR_LISTING_EXPIRED)
        (asserts! (not (is-eq tx-sender (get seller listing))) ERR_SELLER_CANNOT_BUY)
        (asserts! (<= quantity available-quantity) ERR_INSUFFICIENT_SEEDS)
        (asserts! (> quantity u0) ERR_INVALID_QUANTITY)
        (asserts! (> (len shipping-address) u0) ERR_INVALID_LISTING)
        
        ;; Transfer payment to escrow
        (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
        
        ;; Create order
        (map-set orders order-id {
            listing-id: listing-id,
            buyer: tx-sender,
            seller: (get seller listing),
            quantity: quantity,
            total-amount: total-amount,
            marketplace-fee: marketplace-fee,
            seller-amount: seller-amount,
            shipping-address: shipping-address,
            created-at: current-time,
            status: ORDER_PENDING,
            tracking-info: none,
            delivery-confirmed: false
        })
        
        ;; Set up escrow
        (map-set escrow-funds order-id {
            amount: total-amount,
            deposited-at: current-time,
            released: false,
            dispute-deadline: (+ current-time DISPUTE_PERIOD)
        })
        
        ;; Update listing sold quantity
        (let ((new-sold-quantity (+ (get sold-quantity listing) quantity)))
            (map-set listings listing-id (merge listing {
                sold-quantity: new-sold-quantity,
                status: (if (is-eq new-sold-quantity (get quantity listing)) STATUS_SOLD STATUS_ACTIVE)
            }))
        )
        
        ;; Update tracking
        (unwrap! (update-buyer-orders tx-sender order-id) (err u996))
        
        ;; Update counters
        (var-set next-order-id (+ order-id u1))
        (var-set total-sales (+ (var-get total-sales) u1))
        (var-set total-volume (+ (var-get total-volume) total-amount))
        
        (ok order-id)
    )
)

;; Confirm order and provide shipping info
(define-public (confirm-order (order-id uint) (tracking-info (string-ascii 200)))
    (let (
        (order (unwrap! (map-get? orders order-id) ERR_LISTING_NOT_FOUND))
    )
        ;; Only seller can confirm order
        (asserts! (is-eq tx-sender (get seller order)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status order) ORDER_PENDING) ERR_LISTING_NOT_ACTIVE)
        
        ;; Update order status
        (map-set orders order-id (merge order {
            status: ORDER_CONFIRMED,
            tracking-info: (some tracking-info)
        }))
        
        (ok true)
    )
)

;; Mark order as shipped
(define-public (mark-shipped (order-id uint))
    (let (
        (order (unwrap! (map-get? orders order-id) ERR_LISTING_NOT_FOUND))
    )
        ;; Only seller can mark as shipped
        (asserts! (is-eq tx-sender (get seller order)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status order) ORDER_CONFIRMED) ERR_LISTING_NOT_ACTIVE)
        
        ;; Update order status
        (map-set orders order-id (merge order {
            status: ORDER_SHIPPED
        }))
        
        (ok true)
    )
)

;; Confirm delivery and release escrow
(define-public (confirm-delivery (order-id uint))
    (let (
        (order (unwrap! (map-get? orders order-id) ERR_LISTING_NOT_FOUND))
        (escrow (unwrap! (map-get? escrow-funds order-id) ERR_LISTING_NOT_FOUND))
    )
        ;; Only buyer can confirm delivery
        (asserts! (is-eq tx-sender (get buyer order)) ERR_UNAUTHORIZED)
        (asserts! (or (is-eq (get status order) ORDER_SHIPPED) (is-eq (get status order) ORDER_DELIVERED)) ERR_LISTING_NOT_ACTIVE)
        (asserts! (not (get released escrow)) ERR_LISTING_NOT_ACTIVE)
        
        ;; Release funds to seller
        (try! (as-contract (stx-transfer? (get seller-amount order) tx-sender (get seller order))))
        
        ;; Keep marketplace fee
        ;; (marketplace fee stays in contract)
        
        ;; Update escrow status
        (map-set escrow-funds order-id (merge escrow {
            released: true
        }))
        
        ;; Update order status
        (map-set orders order-id (merge order {
            status: ORDER_COMPLETED,
            delivery-confirmed: true
        }))
        
        ;; Update user statistics
        (unwrap! (update-user-stats (get buyer order) (get total-amount order) false) (err u995))
        (unwrap! (update-user-stats (get seller order) (get total-amount order) true) (err u994))
        
        (ok true)
    )
)

;; Cancel listing (only if no pending orders)
(define-public (cancel-listing (listing-id uint))
    (let (
        (listing (unwrap! (map-get? listings listing-id) ERR_LISTING_NOT_FOUND))
    )
        ;; Only seller can cancel listing
        (asserts! (is-eq tx-sender (get seller listing)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status listing) STATUS_ACTIVE) ERR_LISTING_NOT_ACTIVE)
        (asserts! (is-eq (get sold-quantity listing) u0) ERR_LISTING_NOT_ACTIVE)
        
        ;; Update listing status
        (map-set listings listing-id (merge listing {
            status: STATUS_CANCELLED
        }))
        
        (ok true)
    )
)

;; Create dispute
(define-public (create-dispute (order-id uint) (reason (string-ascii 500)))
    (let (
        (order (unwrap! (map-get? orders order-id) ERR_LISTING_NOT_FOUND))
        (escrow (unwrap! (map-get? escrow-funds order-id) ERR_LISTING_NOT_FOUND))
    )
        ;; Only buyer can create dispute
        (asserts! (is-eq tx-sender (get buyer order)) ERR_UNAUTHORIZED)
        (asserts! (not (get released escrow)) ERR_LISTING_NOT_ACTIVE)
        (asserts! (< stacks-block-height (get dispute-deadline escrow)) ERR_DISPUTE_EXPIRED)
        
        ;; Create dispute
        (map-set disputes order-id {
            disputer: tx-sender,
            reason: reason,
            created-at: stacks-block-height,
            resolved: false,
            resolution: none,
            resolver: none
        })
        
        ;; Update order status
        (map-set orders order-id (merge order {
            status: ORDER_DISPUTED
        }))
        
        (ok true)
    )
)

;; Resolve dispute (admin function)
(define-public (resolve-dispute (order-id uint) (refund-buyer bool) (resolution (string-ascii 500)))
    (let (
        (order (unwrap! (map-get? orders order-id) ERR_LISTING_NOT_FOUND))
        (escrow (unwrap! (map-get? escrow-funds order-id) ERR_LISTING_NOT_FOUND))
        (dispute (unwrap! (map-get? disputes order-id) ERR_LISTING_NOT_FOUND))
    )
        ;; Only contract owner can resolve disputes
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (asserts! (not (get resolved dispute)) ERR_LISTING_NOT_ACTIVE)
        (asserts! (not (get released escrow)) ERR_LISTING_NOT_ACTIVE)
        
        ;; Release funds based on resolution
        (if refund-buyer
            ;; Refund buyer
            (try! (as-contract (stx-transfer? (get total-amount order) tx-sender (get buyer order))))
            ;; Pay seller
            (try! (as-contract (stx-transfer? (get seller-amount order) tx-sender (get seller order))))
        )
        
        ;; Update dispute status
        (map-set disputes order-id (merge dispute {
            resolved: true,
            resolution: (some resolution),
            resolver: (some tx-sender)
        }))
        
        ;; Update escrow status
        (map-set escrow-funds order-id (merge escrow {
            released: true
        }))
        
        ;; Update order status
        (map-set orders order-id (merge order {
            status: (if refund-buyer ORDER_DISPUTED ORDER_COMPLETED)
        }))
        
        (ok true)
    )
)

;; Read-only functions

;; Get listing information
(define-read-only (get-listing (listing-id uint))
    (map-get? listings listing-id)
)

;; Get order information
(define-read-only (get-order (order-id uint))
    (map-get? orders order-id)
)

;; Get seller's listings
(define-read-only (get-seller-listings (seller principal))
    (default-to (list) (map-get? seller-listings seller))
)

;; Get buyer's orders
(define-read-only (get-buyer-orders (buyer principal))
    (default-to (list) (map-get? buyer-orders buyer))
)

;; Get user statistics
(define-read-only (get-user-stats (user principal))
    (map-get? marketplace-stats user)
)

;; Get marketplace statistics
(define-read-only (get-marketplace-stats)
    {
        total-listings: (var-get total-listings),
        total-sales: (var-get total-sales),
        total-volume: (var-get total-volume),
        next-listing-id: (var-get next-listing-id),
        next-order-id: (var-get next-order-id),
        marketplace-paused: (var-get marketplace-paused)
    }
)

;; Get escrow information
(define-read-only (get-escrow-info (order-id uint))
    (map-get? escrow-funds order-id)
)

;; Get dispute information
(define-read-only (get-dispute-info (order-id uint))
    (map-get? disputes order-id)
)

;; Admin functions

;; Pause/unpause marketplace
(define-public (set-marketplace-paused (paused bool))
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (var-set marketplace-paused paused)
        (ok true)
    )
)

;; Withdraw marketplace fees
(define-public (withdraw-fees (amount uint))
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER))
    )
)
