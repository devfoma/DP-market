;; Decentralized Prediction Market Contract
;; Allows users to create prediction markets, place bets, and resolve outcomes

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-market-closed (err u104))
(define-constant err-market-resolved (err u105))
(define-constant err-insufficient-funds (err u106))
(define-constant err-unauthorized (err u107))
(define-constant err-invalid-outcome (err u108))
(define-constant err-market-not-resolved (err u109))

;; Data variables
(define-data-var next-market-id uint u1)
(define-data-var platform-fee-rate uint u250) ;; 2.5% (250/10000)

;; Market structure
(define-map markets
  { market-id: uint }
  {
    creator: principal,
    title: (string-ascii 200),
    description: (string-ascii 500),
    end-time: uint,
    resolution-time: uint,
    total-pool: uint,
    yes-pool: uint,
    no-pool: uint,
    resolved: bool,
    outcome: (optional bool),
    creator-fee-rate: uint ;; Creator fee (in basis points, e.g., 100 = 1%)
  }
)

;; User positions in markets
(define-map positions
  { market-id: uint, user: principal, outcome: bool }
  { amount: uint }
)

;; Market creators (for authorization)
(define-map market-creators
  { market-id: uint }
  { creator: principal }
)

;; Helper functions

;; Get current block height as timestamp
(define-private (get-current-time)
  stacks-block-height
)

;; Calculate potential winnings for a bet
(define-private (calculate-winnings (bet-amount uint) (winning-pool uint) (losing-pool uint))
  (if (is-eq losing-pool u0)
    bet-amount
    (+ bet-amount (/ (* bet-amount losing-pool) winning-pool))
  )
)

;; Public functions

;; Create a new prediction market
(define-public (create-market 
  (title (string-ascii 200))
  (description (string-ascii 500))
  (duration-blocks uint)
  (resolution-duration-blocks uint)
  (creator-fee-rate uint))
  (let
    (
      (market-id (var-get next-market-id))
      (current-time (get-current-time))
      (end-time (+ current-time duration-blocks))
      (resolution-time (+ end-time resolution-duration-blocks))
    )
    ;; Validate creator fee rate (max 10%)
    (asserts! (<= creator-fee-rate u1000) err-invalid-amount)
    
    ;; Create the market
    (map-set markets
      { market-id: market-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        end-time: end-time,
        resolution-time: resolution-time,
        total-pool: u0,
        yes-pool: u0,
        no-pool: u0,
        resolved: false,
        outcome: none,
        creator-fee-rate: creator-fee-rate
      }
    )
    
    ;; Set market creator
    (map-set market-creators
      { market-id: market-id }
      { creator: tx-sender }
    )
    
    ;; Increment market ID
    (var-set next-market-id (+ market-id u1))
    
    (ok market-id)
  )
)

;; Place a bet on a market outcome
(define-public (place-bet (market-id uint) (outcome bool) (amount uint))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) err-not-found))
      (current-time (get-current-time))
      (current-position (default-to u0 (get amount (map-get? positions { market-id: market-id, user: tx-sender, outcome: outcome }))))
    )
    ;; Validate bet amount
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Check if market is still open
    (asserts! (< current-time (get end-time market)) err-market-closed)
    
    ;; Check if market is not resolved
    (asserts! (not (get resolved market)) err-market-resolved)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update user position
    (map-set positions
      { market-id: market-id, user: tx-sender, outcome: outcome }
      { amount: (+ current-position amount) }
    )
    
    ;; Update market pools
    (map-set markets
      { market-id: market-id }
      (merge market {
        total-pool: (+ (get total-pool market) amount),
        yes-pool: (if outcome 
                    (+ (get yes-pool market) amount) 
                    (get yes-pool market)),
        no-pool: (if outcome 
                   (get no-pool market) 
                   (+ (get no-pool market) amount))
      })
    )
    
    (ok true)
  )
)

;; Resolve a market (only creator can do this)
(define-public (resolve-market (market-id uint) (outcome bool))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) err-not-found))
      (current-time (get-current-time))
    )
    ;; Check if caller is the market creator
    (asserts! (is-eq tx-sender (get creator market)) err-unauthorized)
    
    ;; Check if market has ended
    (asserts! (>= current-time (get end-time market)) err-market-closed)
    
    ;; Check if market is not already resolved
    (asserts! (not (get resolved market)) err-market-resolved)
    
    ;; Update market with resolution
    (map-set markets
      { market-id: market-id }
      (merge market {
        resolved: true,
        outcome: (some outcome)
      })
    )
    
    (ok true)
  )
)

;; Claim winnings after market resolution
(define-public (claim-winnings (market-id uint))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) err-not-found))
      (winning-outcome (unwrap! (get outcome market) err-market-not-resolved))
      (user-position (unwrap! (map-get? positions { market-id: market-id, user: tx-sender, outcome: winning-outcome }) err-not-found))
      (bet-amount (get amount user-position))
      (winning-pool (if winning-outcome (get yes-pool market) (get no-pool market)))
      (losing-pool (if winning-outcome (get no-pool market) (get yes-pool market)))
      (gross-winnings (calculate-winnings bet-amount winning-pool losing-pool))
      (platform-fee (/ (* gross-winnings (var-get platform-fee-rate)) u10000))
      (creator-fee (/ (* gross-winnings (get creator-fee-rate market)) u10000))
      (net-winnings (- gross-winnings (+ platform-fee creator-fee)))
    )
    ;; Check if market is resolved
    (asserts! (get resolved market) err-market-not-resolved)
    
    ;; Check if user had a winning position
    (asserts! (> bet-amount u0) err-not-found)
    
    ;; Remove user position to prevent double claiming
    (map-delete positions { market-id: market-id, user: tx-sender, outcome: winning-outcome })
    
    ;; Pay out winnings
    (try! (as-contract (stx-transfer? net-winnings tx-sender tx-sender)))
    
    ;; Pay creator fee
    (if (> creator-fee u0)
      (try! (as-contract (stx-transfer? creator-fee tx-sender (get creator market))))
      true
    )
    
    (ok net-winnings)
  )
)

;; Get market information
(define-read-only (get-market (market-id uint))
  (map-get? markets { market-id: market-id })
)

;; Get user position in a market
(define-read-only (get-position (market-id uint) (user principal) (outcome bool))
  (map-get? positions { market-id: market-id, user: user, outcome: outcome })
)

;; Get total number of markets created
(define-read-only (get-total-markets)
  (- (var-get next-market-id) u1)
)

;; Calculate potential winnings for a hypothetical bet
(define-read-only (get-potential-winnings (market-id uint) (outcome bool) (bet-amount uint))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) err-not-found))
      (winning-pool (+ (if outcome (get yes-pool market) (get no-pool market)) bet-amount))
      (losing-pool (if outcome (get no-pool market) (get yes-pool market)))
    )
    (ok (calculate-winnings bet-amount winning-pool losing-pool))
  )
)

;; Get market odds (returns yes-odds and no-odds as percentages * 100)
(define-read-only (get-market-odds (market-id uint))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) err-not-found))
      (yes-pool (get yes-pool market))
      (no-pool (get no-pool market))
      (total-pool (+ yes-pool no-pool))
    )
    (if (is-eq total-pool u0)
      (ok { yes-odds: u5000, no-odds: u5000 }) ;; 50/50 if no bets
      (ok {
        yes-odds: (/ (* yes-pool u10000) total-pool),
        no-odds: (/ (* no-pool u10000) total-pool)
      })
    )
  )
)

;; Admin function to update platform fee (only contract owner)
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount) ;; Max 10%
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

;; Emergency function to resolve market (only contract owner, after resolution period)
(define-public (emergency-resolve-market (market-id uint) (outcome bool))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) err-not-found))
      (current-time (get-current-time))
    )
    ;; Only contract owner can call this
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Can only be used after resolution period has passed
    (asserts! (>= current-time (get resolution-time market)) err-unauthorized)
    
    ;; Check if market is not already resolved
    (asserts! (not (get resolved market)) err-market-resolved)
    
    ;; Update market with resolution
    (map-set markets
      { market-id: market-id }
      (merge market {
        resolved: true,
        outcome: (some outcome)
      })
    )
    
    (ok true)
  )
)