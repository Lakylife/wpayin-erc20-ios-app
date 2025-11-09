#!/bin/bash

# Script to remove mock data references from Preview blocks

FILES=(
"/Users/lakylife/Documents/Wpayin_Wallet/Wpayin_Wallet/Views/Activity/ActivityView.swift"
"/Users/lakylife/Documents/Wpayin_Wallet/Wpayin_Wallet/Views/Swap/SwapView.swift"
"/Users/lakylife/Documents/Wpayin_Wallet/Wpayin_Wallet/Views/Components/LedgerTokenCard.swift"
"/Users/lakylife/Documents/Wpayin_Wallet/Wpayin_Wallet/Views/Components/ExpandableTokenCard.swift"
"/Users/lakylife/Documents/Wpayin_Wallet/Wpayin_Wallet/Views/Components/NFTGridView.swift"
"/Users/lakylife/Documents/Wpayin_Wallet/Wpayin_Wallet/Views/Wallet/AllTransactionsView.swift"
"/Users/lakylife/Documents/Wpayin_Wallet/Wpayin_Wallet/Views/Wallet/AssetDetailView.swift"
"/Users/lakylife/Documents/Wpayin_Wallet/Wpayin_Wallet/Views/Wallet/TokenDetailView.swift"
"/Users/lakylife/Documents/Wpayin_Wallet/Wpayin_Wallet/Views/Wallet/DepositView.swift"
"/Users/lakylife/Documents/Wpayin_Wallet/Wpayin_Wallet/Views/Wallet/WithdrawView.swift"
)

echo "Files to fix:"
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  - $(basename $file)"
    fi
done
