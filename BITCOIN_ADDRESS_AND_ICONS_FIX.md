# Bitcoin Address Derivation & Token Icons Fix

## Bitcoin Address Derivation

### Jak se vytváří Bitcoin adresa?

Bitcoin adresa se derivuje pomocá **WalletCore (Trust Wallet Core)** z vaší seed phrase.

#### Proces derivace:

1. **Seed Phrase** → `HDWallet` objekt
2. **WalletCore** používá **BIP84** (Native SegWit) standard
3. **Derivation Path**: `m/84'/0'/0'/0/{accountIndex}`
4. **Address Format**: `bc1...` (Bech32 - Native SegWit)

#### Kód:

```swift
// MnemonicService.swift
func address(for coin: CoinType, wallet: HDWallet, accountIndex: Int) -> String {
    // WalletCore automatically handles BIP84 for Bitcoin
    let privateKey = wallet.getDerivedKey(
        coin: coin,           // CoinType.bitcoin
        account: 0,           // Account (always 0 for standard)
        change: 0,            // External addresses (not change)
        address: UInt32(accountIndex)  // Address index
    )
    
    let publicKey = privateKey.getPublicKeySecp256k1(compressed: true)
    let address = AnyAddress(publicKey: publicKey, coin: coin)
    return address.description  // Returns bc1... format
}
```

#### Příklad:

**Seed Phrase:**
```
abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
```

**Bitcoin Address (Account 0):**
```
bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu
```

**Bitcoin Address (Account 1):**
```
bc1qnjg0jd8228aq7egyzacy8cys3knf9xvrerkf9g
```

### Proč BIP84 (Native SegWit)?

✅ **Nejnižší transaction fees** (až 40% úspora)  
✅ **Moderní standard** (od 2017)  
✅ **Plná kompatibilita** s většinou exchanges a wallets  
✅ **Better security** (díky SegWit)  

### Srovnání Bitcoin Address Formátů:

| Standard | Prefix | Path | Fee Cost | Status |
|----------|--------|------|----------|--------|
| **BIP44** (Legacy) | `1...` | `m/44'/0'/0'/0/0` | 🔴 Highest | Old |
| **BIP49** (Wrapped SegWit) | `3...` | `m/49'/0'/0'/0/0` | 🟡 Medium | Common |
| **BIP84** (Native SegWit) | `bc1...` | `m/84'/0'/0'/0/0` | 🟢 **Lowest** | ✅ **Recommended** |
| **BIP86** (Taproot) | `bc1p...` | `m/86'/0'/0'/0/0` | 🟢 Lowest+ | Newest |

## Token Icons Fix

### Problém

Po aktivaci Bitcoinu některé tokeny ztratily své ikony, protože:

1. Bitcoin token se vytvářel s `iconUrl: nil`
2. Při mergování tokenů se `nil` přepisovalo přes existující ikony
3. API někdy nevrací ikony okamžitě

### Řešení

#### 1. Default Icon URLs

Přidána `getDefaultIconUrl()` funkce s fallback ikonami pro hlavní tokeny:

```swift
private func getDefaultIconUrl(for symbol: String) -> String? {
    switch symbol.uppercased() {
    case "BTC":
        return "https://assets.coingecko.com/coins/images/1/large/bitcoin.png"
    case "ETH":
        return "https://assets.coingecko.com/coins/images/279/large/ethereum.png"
    case "USDT":
        return "https://assets.coingecko.com/coins/images/325/large/Tether.png"
    case "USDC":
        return "https://assets.coingecko.com/coins/images/6319/large/USD_Coin_icon.png"
    // ... další tokeny
    default:
        return nil
    }
}
```

#### 2. Bitcoin Token Creation

Bitcoin token nyní získává ikonu z API nebo používá default:

```swift
// Try to get BTC price and icon from API
let existingBtcToken = fetchedTokens.first(where: { $0.symbol == "BTC" })
let btcPrice = existingBtcToken?.price ?? 0
let btcIconUrl = existingBtcToken?.iconUrl ?? getDefaultIconUrl(for: "BTC")

let btcToken = Token(
    // ...
    iconUrl: btcIconUrl,  // ✅ Always has icon now
    // ...
)
```

#### 3. Icon Preservation During Merge

Při mergování tokenů se nyní zachovávají ikony:

```swift
// Update or add new tokens (preserve iconUrl if new token doesn't have one)
for token in tokens {
    let key = token.blockchain.rawValue + (token.contractAddress ?? "native")
    
    // If updating existing token and new token has no icon, preserve old icon
    if let existingToken = existingTokensMap[key],
       token.iconUrl == nil,
       let existingIconUrl = existingToken.iconUrl {
        
        // Create new token with preserved iconUrl
        let updatedToken = Token(
            // ... other properties from new token
            iconUrl: existingIconUrl,  // ✅ Preserve existing icon
            // ...
        )
        existingTokensMap[key] = updatedToken
    } else {
        // Use new token as-is (has icon or is completely new)
        existingTokensMap[key] = token
    }
}
```

### Výhody

✅ **Tokeny nikdy neztratí ikony** - Preserved during updates  
✅ **Fallback URLs** - Default icons pokud API selže  
✅ **Bitcoin má vždy ikonu** - Buď z API nebo default  
✅ **Instant display** - Žádné prázdné místo místo ikony  

## Testing

### Test Bitcoin Address Derivation:

1. ✅ Create wallet from seed phrase
2. ✅ Check Bitcoin address format (`bc1...`)
3. ✅ Create Account 2, check different address
4. ✅ Import wallet, verify same addresses

### Test Token Icons:

1. ✅ Load ETH + USDT → Both have icons
2. ✅ Add Bitcoin → BTC has icon, ETH/USDT keep theirs
3. ✅ Remove Bitcoin → ETH/USDT still have icons
4. ✅ Re-add Bitcoin → All icons preserved

## Technical Notes

### WalletCore Integration

**Trust Wallet Core** handles:
- BIP39 mnemonic generation
- HD wallet derivation (BIP32/44/49/84/86)
- Address generation for 50+ blockchains
- Transaction signing
- Public/Private key management

### Icon URL Format

CoinGecko API format:
```
https://assets.coingecko.com/coins/images/{id}/{size}/{name}.png
```

Sizes: `thumb`, `small`, `large`

### Future Improvements

**Consider implementing:**

1. **Local icon cache** - Download and store icons locally
2. **SVG support** - Better quality at any size
3. **Custom icons** - Allow users to upload custom token icons
4. **Icon CDN** - Use IPFS or CDN for faster loading
5. **Placeholder icons** - Generate colored circles with token symbol initials

## Summary

✅ Bitcoin adresy se derivují přes **WalletCore** s **BIP84** (Native SegWit)  
✅ Každý account má unikátní Bitcoin adresu  
✅ Tokeny vždy zachovávají své ikony při update  
✅ Fallback ikony pro případy, kdy API selže  
✅ Clean, maintainable code  

🚀
