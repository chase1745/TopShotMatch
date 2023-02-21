while read line; do
  flow transactions send ./Cadence/transactions/createPlay.cdc "${line}" -n testnet --signer chase3
done < "$1"