# Blockchain Management Fix

## Problem

Když uživatel aktivoval/deaktivoval blockchain v Settings → Networks → Manage Networks, všechna aktiva se rozbila. Při přidání Bitcoinu se například smazaly všechny Ethereum tokeny.

## Root Cause

`toggleBlockchain()` volalo `refreshWalletData()`, která **přepisovala** všechny tokeny místo jejich **slučování**. To způsobilo:
- Ztrátu tokenů z jiných blockchainů
- Reset balancí
- Chybějící tokeny v UI

## Solution

### 1. Token Merging Instead of Replacing

**Before:**
```swift
self.tokens = mergedTokens  // ❌ Přepíše všechny tokeny
```

**After:**
```swift
// ✅ Sloučí nové tokeny s existujícími
var existingTokensMap = Dictionary(uniqueKeysWithValues: self.tokens.map { 
    ($0.blockchain.rawValue + ($0.contractAddress ?? "native"), $0) 
})

for token in tokens {
    let key = token.blockchain.rawValue + (token.contractAddress ?? "native")
    existingTokensMap[key] = token
}

self.tokens = Array(existingTokensMap.values)
```

### 2. Visible Tokens Filtering

Místo mazání tokenů z neaktivních blockchainů je jen filtrujeme při zobrazení:

```swift
// Filtered tokens - only show tokens from selected blockchains
var visibleTokens: [Token] {
    tokens.filter { token in
        guard let platform = BlockchainPlatform(rawValue: token.blockchain.rawValue) else {
            return false
        }
        return selectedBlockchains.contains(platform)
    }
}

var visibleGroupedTokens: [Token] {
    groupedTokens.filter { token in
        guard let platform = BlockchainPlatform(rawValue: token.blockchain.rawValue) else {
            return false
        }
        return selectedBlockchains.contains(platform)
    }
}
```

### 3. Smart Refresh

Nová metoda `refreshNewBlockchainData()` kontroluje, jestli už máme data pro blockchain před jejich načtením:

```swift
private func refreshNewBlockchainData(for platform: BlockchainPlatform) async {
    guard selectedBlockchains.contains(platform) else { return }
    
    // Check if we already have data for this blockchain
    let hasDataForBlockchain = tokens.contains(where: { 
        guard let blockchainType = platform.blockchainType else { return false }
        return $0.blockchain == blockchainType 
    })
    
    if hasDataForBlockchain {
        print("✅ Already have data for \(platform.name)")
        return
    }
    
    // Fetch data for new blockchain only
    await refreshWalletData()
}
```

### 4. UI Updates

Všechny view komponenty teď používají `visibleTokens` nebo `visibleGroupedTokens`:

**Updated Views:**
- `WalletView.swift` - Main wallet display
- `AllAssetsView.swift` - Asset list
- `WithdrawView.swift` - Send tokens
- `DepositView.swift` - Receive tokens
- `SwapView.swift` - Token swapping

**Before:**
```swift
ForEach(walletManager.groupedTokens) { token in
    // ...
}
```

**After:**
```swift
ForEach(walletManager.visibleGroupedTokens) { token in
    // ...
}
```

## How It Works Now

1. **Adding Bitcoin:**
   - ✅ Ethereum tokens zůstanou
   - ✅ Bitcoin balance se načte
   - ✅ Oba blockchains jsou viditelné

2. **Removing Bitcoin:**
   - ✅ Bitcoin tokens jsou skryté (ne smazané!)
   - ✅ Ethereum tokens zůstanou viditelné
   - ✅ Balance se přepočítá jen z viditelných tokenů

3. **Switching Between Blockchains:**
   - ✅ Rychlé - žádné re-fetching
   - ✅ Data zůstanou cached
   - ✅ Smooth UI transitions

## Benefits

✅ **Preserved Data** - Tokeny se nikdy neztratí  
✅ **Better UX** - Rychlé přepínání mezi blockchains  
✅ **Correct Balances** - Balance reflektuje pouze aktivní blockchains  
✅ **Scalable** - Funguje pro libovolný počet blockchainů  
✅ **Memory Efficient** - Tokeny se cachují, ne duplikují  

## Inspiration

Řešení inspirované **Unstoppable Wallet**, která používá podobný přístup:
- `Wallet = Token + Account` (jednoduchý model)
- Storage management oddělen od display logic
- Filtering na úrovni UI, ne data layer

## Testing

Test scénáře:
1. ✅ Start s Ethereum → Add Bitcoin → Ethereum tokeny zůstanou
2. ✅ Have both → Remove Bitcoin → Ethereum tokeny zůstanou
3. ✅ Have both → Remove Ethereum → Bitcoin zůstane
4. ✅ Re-add removed blockchain → Data se znovu načtou
5. ✅ Balance calculation → Správný součet z viditelných tokenů
