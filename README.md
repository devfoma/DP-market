# 🧠 Decentralized Prediction Market

This is a Clarity smart contract for a decentralized prediction market on the Stacks blockchain. It allows users to:

* Create prediction markets
* Bet on binary outcomes (Yes/No)
* Resolve outcomes
* Claim winnings

## 🚀 Features

* **Market Creation** with custom durations and fees
* **Betting** on binary outcomes using STX
* **Resolution** by the market creator or emergency resolution by the contract owner
* **Winnings Claim** with automatic fee deductions (platform + creator)
* **Odds Calculation** and winnings estimations
* Admin control over platform fee rate

---

## 📜 Contract Functions

### 📈 Public Functions

#### `create-market`

Creates a new market.

```lisp
(create-market title description duration-blocks resolution-duration-blocks creator-fee-rate)
```

#### `place-bet`

Place a bet on a market outcome.

```lisp
(place-bet market-id outcome amount)
```

#### `resolve-market`

Resolves a market (only creator can call).

```lisp
(resolve-market market-id outcome)
```

#### `emergency-resolve-market`

Emergency resolution (only contract owner, after resolution time).

```lisp
(emergency-resolve-market market-id outcome)
```

#### `claim-winnings`

Claim your winnings if you bet on the correct outcome.

```lisp
(claim-winnings market-id)
```

#### `set-platform-fee-rate`

Admin function to set the platform fee.

```lisp
(set-platform-fee-rate new-rate)
```

---

### 📖 Read-Only Functions

#### `get-market`

Returns market details.

```lisp
(get-market market-id)
```

#### `get-position`

Returns the amount a user has bet on a specific outcome in a market.

```lisp
(get-position market-id user outcome)
```

#### `get-total-markets`

Returns the total number of markets created.

#### `get-potential-winnings`

Estimates potential winnings for a hypothetical bet.

```lisp
(get-potential-winnings market-id outcome bet-amount)
```

#### `get-market-odds`

Returns current odds for both Yes and No outcomes as percentages \* 100.

---

## 💰 Fees

* **Platform Fee**: Default is 2.5% (can be updated by contract owner)
* **Creator Fee**: Custom per-market, up to 10%

---

## 🛡 Errors

| Error Name                | Code | Description                           |
| ------------------------- | ---- | ------------------------------------- |
| `err-owner-only`          | 100  | Action can only be performed by owner |
| `err-not-found`           | 101  | Resource not found                    |
| `err-already-exists`      | 102  | Resource already exists               |
| `err-invalid-amount`      | 103  | Invalid amount supplied               |
| `err-market-closed`       | 104  | Market is no longer accepting bets    |
| `err-market-resolved`     | 105  | Market already resolved               |
| `err-insufficient-funds`  | 106  | Not enough STX provided               |
| `err-unauthorized`        | 107  | Caller is not authorized              |
| `err-invalid-outcome`     | 108  | Outcome must be boolean (true/false)  |
| `err-market-not-resolved` | 109  | Outcome not yet resolved              |

---

## 🛠 Deployment Notes

* Deploy on the Stacks blockchain using a Clarity-compatible environment.
* Ensure the deploying principal is trusted as the **platform owner**.
* All STX transfers are handled via `stx-transfer?`.

---

## 📌 TODO / Improvements

* Add event logging for key state changes (market creation, resolution, winnings claim)
* Add support for non-binary outcomes in future versions
* Frontend DApp integration
* Persistent claim tracking to prevent duplicate claims (in case of multiple outcomes)

---

## 📃 License

MIT License © 2025
