# Seed Marketplace - On-chain Provenance System 🗂️ Sprout

A comprehensive decentralized marketplace for seeds with complete on-chain provenance tracking built on the Stacks blockchain using Clarity smart contracts.

## Overview

The Seed Marketplace system provides a transparent, trustworthy platform for buying and selling seeds with complete provenance tracking. Every seed batch is tracked from origin to final sale, ensuring authenticity, quality, and traceability throughout the supply chain.

## Key Features

### 🌱 **Seed Registration & Provenance**
- Complete seed lifecycle tracking from farm to marketplace
- Verifiable origin and quality certifications
- Batch tracking with unique identifiers
- Genetic lineage and breeding information

### 🏪 **Marketplace Operations**
- Decentralized seed buying and selling
- Price discovery and fair market mechanisms  
- Quality-based pricing and reputation system
- Secure escrow and payment processing

### 🔍 **Verification & Authenticity**
- On-chain proof of seed authenticity
- Certification by authorized growers and inspectors
- Quality metrics and germination guarantees
- Anti-counterfeiting measures

### 📊 **Supply Chain Transparency**
- End-to-end traceability from source to buyer
- Environmental and growing condition records
- Transportation and storage history
- Quality testing and inspection logs

## Smart Contract Architecture

The system consists of two main contracts:

1. **`seed-registry.clar`** - Core seed registration, provenance tracking, and authenticity verification
2. **`marketplace.clar`** - Trading functionality, escrow services, and market operations

## Contract Functions

### Seed Registry Contract
- `register-seed-batch` - Register new seed batch with provenance data
- `update-provenance` - Add provenance information during supply chain
- `verify-authenticity` - Verify seed authenticity and certifications
- `get-seed-info` - Retrieve complete seed information and history
- `certify-grower` - Authorize trusted growers and inspectors

### Marketplace Contract  
- `list-seeds` - List seeds for sale on the marketplace
- `purchase-seeds` - Buy seeds with escrow protection
- `process-payment` - Handle payment and delivery confirmation
- `dispute-resolution` - Handle disputes between buyers and sellers
- `get-market-data` - Access marketplace statistics and pricing

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js for running tests
- Stacks wallet for interaction

### Installation

1. Clone the repository:
   \`\`\`bash
   git clone https://github.com/sasunayunmi-hub/seed-marketplace.git
   cd seed-marketplace
   \`\`\`

2. Install dependencies:
   \`\`\`bash
   npm install
   \`\`\`

3. Check contract syntax:
   \`\`\`bash
   clarinet check
   \`\`\`

4. Run tests:
   \`\`\`bash
   npm test
   \`\`\`

## Usage Examples

### Registering a Seed Batch
\`\`\`clarity
(contract-call? .seed-registry register-seed-batch
  "Heirloom Tomato Cherokee Purple" ;; variety name
  'ST1GROWER123                     ;; grower principal
  u1000                             ;; quantity (seeds)
  "Farm Location: Oregon, USA"      ;; origin info
  u2024                             ;; harvest year
  "Organic Certified")              ;; quality certifications
\`\`\`

### Listing Seeds on Marketplace
\`\`\`clarity
(contract-call? .marketplace list-seeds
  u1                                ;; seed-batch-id
  u500                              ;; quantity to sell
  u100                              ;; price per seed (in microSTX)
  u30                               ;; listing duration (days)
  "Premium organic heirloom seeds") ;; description
\`\`\`

### Purchasing Seeds
\`\`\`clarity
(contract-call? .marketplace purchase-seeds
  u1                               ;; listing-id
  u50                              ;; quantity to purchase
  "Delivery Address: 123 Garden St") ;; shipping info
\`\`\`

## Data Structures

### Seed Batch Information
- **Batch ID**: Unique identifier for each seed batch
- **Variety**: Seed variety name and genetic information
- **Grower**: Principal of the registered grower
- **Origin**: Farm location and growing conditions
- **Harvest Info**: Date, yield, and quality metrics
- **Certifications**: Organic, heirloom, or other quality certifications
- **Provenance Trail**: Complete supply chain history

### Marketplace Listings
- **Listing ID**: Unique marketplace listing identifier
- **Seed Batch**: Reference to registered seed batch
- **Seller**: Principal of the seed seller
- **Pricing**: Price per unit and total quantity
- **Status**: Available, sold, or disputed
- **Terms**: Delivery, guarantees, and conditions

## Testing

The project includes comprehensive test suites covering:
- Seed registration and provenance tracking
- Marketplace listing and purchase workflows
- Authentication and authorization
- Edge cases and error handling
- Integration between contracts

Run tests with:
\`\`\`bash
npm test
\`\`\`

## Security Features

- **Authentication**: Only authorized growers can register seed batches
- **Verification**: Multi-level verification for authenticity
- **Escrow Protection**: Secure payment handling with dispute resolution
- **Anti-fraud**: Prevents duplicate registrations and fake listings
- **Data Integrity**: Immutable provenance records on blockchain

## Use Cases

### For Growers
- Register and certify seed batches
- Build reputation through quality tracking
- Access direct-to-consumer markets
- Prove authenticity and quality claims

### For Buyers
- Verify seed authenticity and provenance
- Access detailed growing information
- Purchase with escrow protection
- Track seeds from source to garden

### For Inspectors/Certifiers
- Provide quality certifications
- Verify growing conditions and practices
- Build trust in the seed marketplace
- Enable premium pricing for certified seeds

## Future Enhancements

The modular design allows for future improvements:
- Integration with IoT sensors for growing condition tracking
- AI-powered quality assessment and pricing
- Cross-chain interoperability for global markets
- Automated compliance with agricultural regulations
- Integration with shipping and logistics providers

## Contributing

1. Fork the repository
2. Create a feature branch (\`git checkout -b feature/amazing-feature\`)
3. Commit your changes (\`git commit -m 'Add amazing feature'\`)
4. Push to the branch (\`git push origin feature/amazing-feature\`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions, issues, or support:
- Create an issue on GitHub
- Contact the development team
- Review the documentation

---

**Disclaimer**: This smart contract system is for educational and demonstration purposes. Always conduct thorough testing and audits before deploying to mainnet with real funds.
