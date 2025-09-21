;; Seed Registry Contract - On-chain Provenance for Seeds
;; Core seed registration, provenance tracking, and authenticity verification

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_BATCH (err u101))
(define-constant ERR_BATCH_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_CERTIFIED (err u103))
(define-constant ERR_INVALID_GROWER (err u104))
(define-constant ERR_INVALID_QUANTITY (err u105))
(define-constant ERR_DUPLICATE_BATCH (err u106))
(define-constant ERR_INSUFFICIENT_QUANTITY (err u107))
(define-constant ERR_BATCH_EXPIRED (err u108))

;; Certification Types
(define-constant CERT_ORGANIC u1)
(define-constant CERT_HEIRLOOM u2)
(define-constant CERT_NON_GMO u3)
(define-constant CERT_OPEN_POLLINATED u4)
(define-constant CERT_RARE_VARIETY u5)

;; Batch Status
(define-constant STATUS_REGISTERED u0)
(define-constant STATUS_CERTIFIED u1)
(define-constant STATUS_AVAILABLE u2)
(define-constant STATUS_SOLD u3)
(define-constant STATUS_EXPIRED u4)

;; Configuration Constants
(define-constant MAX_VARIETY_NAME_LENGTH u100)
(define-constant MAX_ORIGIN_INFO_LENGTH u200)
(define-constant MAX_CERTIFICATIONS_LENGTH u300)
(define-constant MAX_PROVENANCE_ENTRIES u50)
(define-constant MIN_QUANTITY u1)
(define-constant MAX_QUANTITY u1000000) ;; 1 million seeds per batch

;; Data Variables
(define-data-var next-batch-id uint u1)
(define-data-var total-batches-registered uint u0)
(define-data-var total-seeds-registered uint u0)
(define-data-var contract-paused bool false)

;; Data Maps
(define-map seed-batches
    uint ;; batch-id
    {
        variety-name: (string-ascii 100),
        grower: principal,
        quantity: uint,
        available-quantity: uint,
        origin-info: (string-ascii 200),
        harvest-year: uint,
        quality-certifications: (string-ascii 300),
        status: uint,
        registered-at: uint,
        certification-level: uint,
        genetic-info: (string-ascii 150),
        germination-rate: uint ;; percentage (0-100)
    }
)

(define-map grower-certifications
    principal ;; grower address
    {
        certified: bool,
        certification-date: uint,
        certifier: principal,
        reputation-score: uint, ;; 0-100 scale
        total-batches: uint,
        specialties: (list 10 (string-ascii 50))
    }
)

(define-map batch-provenance
    uint ;; batch-id
    (list 50 {
        event-type: (string-ascii 50),
        description: (string-ascii 200),
        timestamp: uint,
        actor: principal,
        location: (string-ascii 100)
    })
)

(define-map grower-batches
    principal ;; grower address
    (list 100 uint) ;; list of batch IDs
)

(define-map batch-genetics
    uint ;; batch-id
    {
        parent-varieties: (list 5 (string-ascii 100)),
        breeding-method: (string-ascii 100),
        generation: uint,
        traits: (list 10 (string-ascii 50)),
        resistance-info: (string-ascii 200)
    }
)

(define-map certification-authorities
    principal ;; certifier address
    {
        authorized: bool,
        name: (string-ascii 100),
        specialization: (string-ascii 100),
        certifications-issued: uint
    }
)

;; Private Functions

(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-certified-grower (grower principal))
    (match (map-get? grower-certifications grower)
        cert (get certified cert)
        false
    )
)

(define-private (is-authorized-certifier (certifier principal))
    (match (map-get? certification-authorities certifier)
        auth (get authorized auth)
        false
    )
)

(define-private (is-valid-quantity (quantity uint))
    (and (>= quantity MIN_QUANTITY) (<= quantity MAX_QUANTITY))
)

(define-private (update-grower-batches (grower principal) (batch-id uint))
    (let ((current-batches (default-to (list) (map-get? grower-batches grower))))
        (begin
            (map-set grower-batches grower (unwrap! (as-max-len? (append current-batches batch-id) u100) (err u999)))
            (ok true)
        )
    )
)

(define-private (add-provenance-entry (batch-id uint) (event-type (string-ascii 50)) (description (string-ascii 200)) (location (string-ascii 100)))
    (let ((current-provenance (default-to (list) (map-get? batch-provenance batch-id))))
        (let ((new-entry {
                event-type: event-type,
                description: description,
                timestamp: stacks-block-height,
                actor: tx-sender,
                location: location
            }))
            (begin
                (map-set batch-provenance batch-id (unwrap! (as-max-len? (append current-provenance new-entry) u50) (err u998)))
                (ok true)
            )
        )
    )
)

;; Public Functions

;; Register a new seed batch
(define-public (register-seed-batch (variety-name (string-ascii 100)) (quantity uint) (origin-info (string-ascii 200)) (harvest-year uint) (quality-certifications (string-ascii 300)) (genetic-info (string-ascii 150)) (germination-rate uint))
    (let (
        (batch-id (var-get next-batch-id))
        (current-block-height stacks-block-height)
    )
        ;; Validation checks
        (asserts! (not (var-get contract-paused)) (err u109))
        (asserts! (is-certified-grower tx-sender) ERR_INVALID_GROWER)
        (asserts! (is-valid-quantity quantity) ERR_INVALID_QUANTITY)
        (asserts! (> (len variety-name) u0) ERR_INVALID_BATCH)
        (asserts! (<= germination-rate u100) ERR_INVALID_BATCH)
        
        ;; Create the seed batch
        (map-set seed-batches batch-id {
            variety-name: variety-name,
            grower: tx-sender,
            quantity: quantity,
            available-quantity: quantity,
            origin-info: origin-info,
            harvest-year: harvest-year,
            quality-certifications: quality-certifications,
            status: STATUS_REGISTERED,
            registered-at: current-block-height,
            certification-level: u0,
            genetic-info: genetic-info,
            germination-rate: germination-rate
        })
        
        ;; Update tracking
        (unwrap! (update-grower-batches tx-sender batch-id) (err u997))
        (unwrap! (add-provenance-entry batch-id "REGISTRATION" "Seed batch registered on blockchain" "") (err u996))
        
        ;; Update counters
        (var-set next-batch-id (+ batch-id u1))
        (var-set total-batches-registered (+ (var-get total-batches-registered) u1))
        (var-set total-seeds-registered (+ (var-get total-seeds-registered) quantity))
        
        (ok batch-id)
    )
)

;; Certify a grower
(define-public (certify-grower (grower principal) (specialties (list 10 (string-ascii 50))))
    (begin
        ;; Only authorized certifiers or contract owner can certify growers
        (asserts! (or (is-contract-owner) (is-authorized-certifier tx-sender)) ERR_UNAUTHORIZED)
        
        ;; Create or update grower certification
        (map-set grower-certifications grower {
            certified: true,
            certification-date: stacks-block-height,
            certifier: tx-sender,
            reputation-score: u50, ;; Start with neutral reputation
            total-batches: u0,
            specialties: specialties
        })
        
        (ok true)
    )
)

;; Update provenance information
(define-public (update-provenance (batch-id uint) (event-type (string-ascii 50)) (description (string-ascii 200)) (location (string-ascii 100)))
    (let (
        (batch (unwrap! (map-get? seed-batches batch-id) ERR_BATCH_NOT_FOUND))
    )
        ;; Only batch owner or authorized certifiers can update provenance
        (asserts! (or (is-eq tx-sender (get grower batch)) (is-authorized-certifier tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (not (var-get contract-paused)) (err u109))
        
        ;; Add provenance entry
        (unwrap! (add-provenance-entry batch-id event-type description location) (err u995))
        
        (ok true)
    )
)

;; Certify seed batch quality
(define-public (certify-batch (batch-id uint) (certification-type uint))
    (let (
        (batch (unwrap! (map-get? seed-batches batch-id) ERR_BATCH_NOT_FOUND))
    )
        ;; Only authorized certifiers can certify batches
        (asserts! (is-authorized-certifier tx-sender) ERR_UNAUTHORIZED)
        (asserts! (not (var-get contract-paused)) (err u109))
        (asserts! (<= certification-type CERT_RARE_VARIETY) ERR_INVALID_BATCH)
        
        ;; Update batch certification
        (map-set seed-batches batch-id (merge batch {
            status: STATUS_CERTIFIED,
            certification-level: certification-type
        }))
        
        ;; Add provenance entry
        (unwrap! (add-provenance-entry batch-id "CERTIFICATION" "Batch quality certified" "") (err u994))
        
        ;; Update certifier statistics
        (match (map-get? certification-authorities tx-sender)
            auth (map-set certification-authorities tx-sender (merge auth {
                certifications-issued: (+ (get certifications-issued auth) u1)
            }))
            false ;; Should not happen if authorized
        )
        
        (ok true)
    )
)

;; Update available quantity (for marketplace integration)
(define-public (update-available-quantity (batch-id uint) (new-quantity uint))
    (let (
        (batch (unwrap! (map-get? seed-batches batch-id) ERR_BATCH_NOT_FOUND))
    )
        ;; Only batch owner can update available quantity
        (asserts! (is-eq tx-sender (get grower batch)) ERR_UNAUTHORIZED)
        (asserts! (<= new-quantity (get quantity batch)) ERR_INVALID_QUANTITY)
        
        ;; Update available quantity
        (map-set seed-batches batch-id (merge batch {
            available-quantity: new-quantity,
            status: (if (is-eq new-quantity u0) STATUS_SOLD STATUS_AVAILABLE)
        }))
        
        (ok true)
    )
)

;; Add genetic information
(define-public (add-genetic-info (batch-id uint) (parent-varieties (list 5 (string-ascii 100))) (breeding-method (string-ascii 100)) (generation uint) (traits (list 10 (string-ascii 50))) (resistance-info (string-ascii 200)))
    (let (
        (batch (unwrap! (map-get? seed-batches batch-id) ERR_BATCH_NOT_FOUND))
    )
        ;; Only batch owner or authorized certifiers can add genetic info
        (asserts! (or (is-eq tx-sender (get grower batch)) (is-authorized-certifier tx-sender)) ERR_UNAUTHORIZED)
        
        ;; Store genetic information
        (map-set batch-genetics batch-id {
            parent-varieties: parent-varieties,
            breeding-method: breeding-method,
            generation: generation,
            traits: traits,
            resistance-info: resistance-info
        })
        
        ;; Add provenance entry
        (unwrap! (add-provenance-entry batch-id "GENETIC_INFO" "Genetic information added" "") (err u993))
        
        (ok true)
    )
)

;; Read-only functions

;; Get seed batch information
(define-read-only (get-seed-batch (batch-id uint))
    (map-get? seed-batches batch-id)
)

;; Get batch provenance trail
(define-read-only (get-batch-provenance (batch-id uint))
    (default-to (list) (map-get? batch-provenance batch-id))
)

;; Get grower information
(define-read-only (get-grower-info (grower principal))
    (map-get? grower-certifications grower)
)

;; Get grower's batches
(define-read-only (get-grower-batches (grower principal))
    (default-to (list) (map-get? grower-batches grower))
)

;; Get genetic information
(define-read-only (get-genetic-info (batch-id uint))
    (map-get? batch-genetics batch-id)
)

;; Get registry statistics
(define-read-only (get-registry-stats)
    {
        total-batches: (var-get total-batches-registered),
        total-seeds: (var-get total-seeds-registered),
        next-batch-id: (var-get next-batch-id),
        contract-paused: (var-get contract-paused)
    }
)

;; Verify seed authenticity
(define-read-only (verify-authenticity (batch-id uint))
    (match (map-get? seed-batches batch-id)
        batch {
            exists: true,
            certified: (>= (get certification-level batch) u1),
            grower-verified: (is-certified-grower (get grower batch)),
            status: (get status batch),
            germination-rate: (get germination-rate batch)
        }
        {
            exists: false,
            certified: false,
            grower-verified: false,
            status: u999,
            germination-rate: u0
        }
    )
)

;; Admin functions

;; Add certification authority
(define-public (add-certification-authority (certifier principal) (name (string-ascii 100)) (specialization (string-ascii 100)))
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (map-set certification-authorities certifier {
            authorized: true,
            name: name,
            specialization: specialization,
            certifications-issued: u0
        })
        (ok true)
    )
)

;; Pause/unpause contract
(define-public (set-contract-paused (paused bool))
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (var-set contract-paused paused)
        (ok true)
    )
)
