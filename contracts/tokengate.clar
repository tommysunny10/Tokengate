;; TokenGate - A token-gated access control smart contract
;; Version: v1.1 - Fixed dynamic trait resolution

;; ----------------------------
;; Configurable Constants
;; ----------------------------

(define-constant contract-owner tx-sender) 
(define-constant err-owner-only (err u100))
(define-constant err-token-call-failed (err u101))
(define-constant err-insufficient-access (err u102))
(define-constant err-wrong-token (err u103))

;; SIP-010 token trait definition
(define-trait sip-010-token
  (
    (get-balance (principal) (response uint uint))
  )
)

(define-data-var token-contract principal 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9)

;; Access tiers
(define-data-var access-tiers (list 10 {level: uint, min: uint})
  (list 
    {level: u1, min: u100}   ;; Bronze
    {level: u2, min: u500}   ;; Silver
    {level: u3, min: u1000}  ;; Gold
  ))

;; ----------------------------
;; Admin-Only Functions
;; ----------------------------

(define-public (set-token-contract (new-contract principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set token-contract new-contract)
    (ok true)))

(define-public (set-access-tiers (new-tiers (list 10 {level: uint, min: uint})))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set access-tiers new-tiers)
    (ok true)))

;; ----------------------------
;; Helper Functions
;; ----------------------------

(define-private (check-tier-level (tier {level: uint, min: uint}) (data {balance: uint, highest-level: uint}))
  (if (>= (get balance data) (get min tier))
      {balance: (get balance data), highest-level: (get level tier)}
      data))

;; ----------------------------
;; Public Access Logic (Corrected Trait usage)
;; ----------------------------

(define-read-only (get-token-contract)
  (var-get token-contract))

(define-read-only (get-access-tiers)
  (var-get access-tiers))

;; FIXED: Added <sip-010-token> trait as a parameter
(define-public (check-access-level (user principal) (token-trait <sip-010-token>))
  (let (
    (stored-token (var-get token-contract))
    (tiers (var-get access-tiers))
  )
    ;; Security check: ensure the passed trait is the token we actually gate for
    (asserts! (is-eq (contract-of token-trait) stored-token) err-wrong-token)
    
    (match (contract-call? token-trait get-balance user)
      success (let (
        (initial-data {balance: success, highest-level: u0})
        (result (fold check-tier-level tiers initial-data))
      )
        (ok (get highest-level result)))
      error err-token-call-failed)))

;; FIXED: Parameterized with trait
(define-public (has-access (user principal) (required-level uint) (token-trait <sip-010-token>))
  (match (check-access-level user token-trait)
    success (ok (>= success required-level))
    error (err error)))

;; FIXED: Parameterized with trait
(define-public (get-user-balance (user principal) (token-trait <sip-010-token>))
  (begin
    (asserts! (is-eq (contract-of token-trait) (var-get token-contract)) err-wrong-token)
    (contract-call? token-trait get-balance user)))

;; ----------------------------
;; Public Access Functions
;; ----------------------------

;; FIXED: Parameterized with trait
(define-public (verify-access (required-level uint) (token-trait <sip-010-token>))
  (let (
    (user-level (try! (check-access-level tx-sender token-trait)))
  )
    (asserts! (>= user-level required-level) err-insufficient-access)
    (ok true)))

(define-public (check-my-access (token-trait <sip-010-token>))
  (check-access-level tx-sender token-trait))