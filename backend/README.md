# Tourist ID Backend Service

This backend service handles the secure minting of Tourist ID NFTs using the government's private key. It provides a REST API for the Flutter app to create tourist IDs without exposing sensitive blockchain credentials.

## Features

- 🔐 **Secure Private Key Management**: Government wallet private key stored securely in environment variables
- 🚀 **REST API**: Clean API endpoints for minting and managing tourist IDs
- 🛡️ **Security**: API key authentication, rate limiting, and input validation
- 📝 **Logging**: Comprehensive logging for monitoring and debugging
- ⚡ **Performance**: Optimized gas estimation and transaction handling

## Setup Instructions

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Environment Configuration

1. Copy the example environment file:
```bash
cp env.example .env
```

2. Edit `.env` with your actual values:
```env
# Server Configuration
PORT=3000
NODE_ENV=development

# Blockchain Configuration
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/-RGNirb5XtTS_mKCFbeMY
CONTRACT_ADDRESS=0x341179f8cdd0e4873cda6392938d539afea50d6e
CHAIN_ID=11155111

# Government Wallet (CRITICAL: Keep this secure!)
GOVERNMENT_PRIVATE_KEY=your_government_wallet_private_key_here
GOVERNMENT_ADDRESS=your_government_wallet_address_here

# Security
JWT_SECRET=your_jwt_secret_here
API_KEY=your_api_key_here

# IPFS Configuration
IPFS_GATEWAY_URL=https://ipfs.io/ipfs/

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Logging
LOG_LEVEL=info
```

### 3. Get Your Government Wallet Private Key

1. **From MetaMask**:
   - Open MetaMask
   - Click on your account (the one that deployed the contract)
   - Click the three dots (⋮) → "Account details"
   - Click "Export private key"
   - Enter your password and copy the private key

2. **Add to .env**:
   ```env
   GOVERNMENT_PRIVATE_KEY=your_64_character_hex_private_key_here
   GOVERNMENT_ADDRESS=0xYourWalletAddress
   ```

### 4. Generate API Key

Create a secure API key for your Flutter app:
```bash
# Generate a random API key
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Add it to your `.env`:
```env
API_KEY=your_generated_api_key_here
```

### 5. Copy Contract ABI

Make sure the contract ABI file is in the correct location:
```bash
# Copy from your Flutter project
cp ../assets/contracts/TouristID.json ./assets/contracts/
```

### 6. Start the Server

```bash
# Development mode
npm run dev

# Production mode
npm start
```

The server will start on `http://localhost:3000`

## API Endpoints

### Health Check
```
GET /health
```

### Mint Tourist ID
```
POST /api/mint-id
Headers:
  x-api-key: your_api_key
  Content-Type: application/json

Body:
{
  "touristAddress": "0x...",
  "touristIdHash": "0x...",
  "validUntil": "2024-12-31T23:59:59.000Z",
  "metadataCID": "Qm...",
  "issuerInfo": "Government Tourism Authority"
}
```

### Get Tourist ID
```
GET /api/tourist-id/:tokenId
Headers:
  x-api-key: your_api_key
```

### Get All Tourist IDs
```
GET /api/tourist-ids?page=1&limit=50
Headers:
  x-api-key: your_api_key
```

## Flutter Integration

Update your Flutter app's `BackendMintService`:

```dart
// In lib/services/backend_mint_service.dart
static const String _baseUrl = 'http://localhost:3000/api'; // Your backend URL
static const String _apiKey = 'your_api_key_here'; // Same as in .env
```

## Security Best Practices

1. **Never commit `.env` file** to version control
2. **Use HTTPS** in production
3. **Rotate API keys** regularly
4. **Monitor logs** for suspicious activity
5. **Use environment-specific configurations**
6. **Consider using AWS KMS/Azure Key Vault** for production private key storage

## Production Deployment

### Using PM2
```bash
npm install -g pm2
pm2 start server.js --name tourist-id-backend
pm2 startup
pm2 save
```

### Using Docker
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

### Environment Variables in Production
- Use your cloud provider's secret management (AWS Secrets Manager, Azure Key Vault, etc.)
- Never hardcode sensitive values
- Use different API keys for different environments

## Monitoring

- Logs are stored in `./logs/` directory
- Monitor gas prices and transaction success rates
- Set up alerts for failed transactions
- Track API usage and rate limiting

## Troubleshooting

### Common Issues

1. **"GOVERNMENT_PRIVATE_KEY not found"**
   - Check your `.env` file exists and has the correct variable name
   - Ensure the private key is 64 characters (without 0x prefix)

2. **"Transaction failed"**
   - Check if the government wallet has enough ETH for gas
   - Verify the contract address is correct
   - Check if the RPC URL is working

3. **"Invalid API key"**
   - Ensure the API key in your Flutter app matches the one in `.env`
   - Check the `x-api-key` header is being sent correctly

### Getting Help

- Check the logs in `./logs/` directory
- Verify your blockchain configuration
- Test the health endpoint: `GET /health`







