A blockchain-powered marketplace for sustainable construction material reuse and recycling, built on the Stacks blockchain using Clarity smart contracts.

## 🌱 Problem & Solution

**Problem**: Construction waste contributes significantly to landfills and environmental degradation.

**Solution**: A decentralized marketplace that enables construction companies to buy, sell, and track recycled materials while monitoring their environmental impact.

## ✨ Features

- 📄 **Material Passports**: Immutable blockchain records for construction materials
- 🔄 **Tokenized Resale Market**: STX-powered trading of construction materials  
- 🌍 **CO₂ Footprint Tracking**: Monitor and calculate environmental impact savings
- 👤 **User Reputation System**: Build trust through transaction history
- 💰 **Platform Revenue Model**: 5% fee on transactions

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Node.js](https://nodejs.org/) for package management

### Installation

```bash
git clone https://github.com/TegaEmomotimi/Circular-Construction-Materials-Marketplace
cd Circular-Construction-Materials-Marketplace
npm install
```

### 🧪 Testing

```bash
clarinet test
```

### 📜 Contract Deployment

```bash
clarinet deploy
```

## 📖 Usage Guide

### Creating Material Passports

Register construction materials with their environmental data:

```clarity
(contract-call? .circular-construction-materials-marketplace create-material-passport
  "Steel Beams"           ;; material-type
  "Office Building A"     ;; origin-project  
  "Grade A"              ;; quality-grade
  u1000                  ;; quantity (units)
  u5000                  ;; co2-footprint (kg CO₂)
  "New York, NY"         ;; location
  u50                    ;; price-per-unit (microSTX)
)
```

### Listing Materials for Sale

```clarity
(contract-call? .circular-construction-materials-marketplace list-material-for-sale
  u1                     ;; material-id
  u500                   ;; quantity-to-sell
  u45                    ;; price-per-unit (microSTX)
)
```

### Purchasing Materials

```clarity
(contract-call? .circular-construction-materials-marketplace purchase-material
  u1                     ;; listing-id
  u100                   ;; quantity-to-buy
)
```

### Viewing Material Information

```clarity
(contract-call? .circular-construction-materials-marketplace get-material-passport u1)
(contract-call? .circular-construction-materials-marketplace get-available-materials)
(contract-call? .circular-construction-materials-marketplace search-materials-by-type "Steel Beams")
```

## 📊 Key Functions

| Function | Description |
|----------|-------------|
| `create-material-passport` | Register new construction materials |
| `list-material-for-sale` | List materials on the marketplace |
| `purchase-material` | Buy materials from other users |
| `get-material-passport` | View material details and provenance |
| `get-user-profile` | Check user stats and reputation |
| `calculate-co2-impact` | Calculate environmental savings |

## 🏛️ Contract Architecture

### Data Structures

- **Material Passports**: Core material information with provenance
- **Material Listings**: Active marketplace listings
- **Transactions**: Purchase history and CO₂ impact
- **User Profiles**: Reputation and activity tracking

### Security Features

- ✅ Owner-only functions for material management
- ✅ Authorization checks for all state-changing operations
- ✅ Input validation and error handling
- ✅ STX balance verification before transfers

## 🌍 Environmental Impact

Every transaction calculates and tracks CO₂ savings, promoting sustainable construction practices and providing transparency into environmental benefits.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests with `clarinet test`
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Documentation](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)
