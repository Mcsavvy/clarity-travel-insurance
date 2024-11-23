;; Travel Insurance Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-not-active (err u103))
(define-constant err-already-claimed (err u104))

;; Data Variables
(define-data-var insurance-fee uint u100)
(define-data-var claim-period uint u30) ;; in days

;; Data Maps
(define-map policies
    principal
    {
        policy-id: uint,
        start-date: uint,
        end-date: uint,
        destination: (string-ascii 50),
        premium-paid: uint,
        is-active: bool,
        is-claimed: bool
    }
)

(define-map claims
    uint
    {
        policy-holder: principal,
        claim-date: uint,
        reason: (string-ascii 100),
        amount: uint,
        status: (string-ascii 20)
    }
)

;; Get insurance fee
(define-read-only (get-insurance-fee)
    (ok (var-get insurance-fee))
)

;; Update insurance fee - owner only
(define-public (update-insurance-fee (new-fee uint))
    (if (is-eq tx-sender contract-owner)
        (ok (var-set insurance-fee new-fee))
        err-owner-only
    )
)

;; Purchase insurance policy
(define-public (purchase-policy 
    (start-date uint)
    (end-date uint)
    (destination (string-ascii 50)))
    
    (let ((policy-exists (default-to 
        {
            policy-id: u0,
            start-date: u0,
            end-date: u0,
            destination: "",
            premium-paid: u0,
            is-active: false,
            is-claimed: false
        }
        (map-get? policies tx-sender))))
        
        (if (get is-active policy-exists)
            err-already-exists
            (begin
                (try! (stx-transfer? (var-get insurance-fee) tx-sender contract-owner))
                (ok (map-set policies tx-sender {
                    policy-id: (+ u1 (get policy-id policy-exists)),
                    start-date: start-date,
                    end-date: end-date,
                    destination: destination,
                    premium-paid: (var-get insurance-fee),
                    is-active: true,
                    is-claimed: false
                }))
            )
        )
    )
)

;; File an insurance claim
(define-public (file-claim 
    (policy-id uint)
    (reason (string-ascii 100))
    (amount uint))
    
    (let ((policy (default-to
        {
            policy-id: u0,
            start-date: u0,
            end-date: u0,
            destination: "",
            premium-paid: u0,
            is-active: false,
            is-claimed: false
        }
        (map-get? policies tx-sender))))
        
        (asserts! (get is-active policy) err-not-active)
        (asserts! (not (get is-claimed policy)) err-already-claimed)
        
        (ok (map-set claims policy-id {
            policy-holder: tx-sender,
            claim-date: block-height,
            reason: reason,
            amount: amount,
            status: "PENDING"
        }))
    )
)

;; Approve claim - owner only
(define-public (approve-claim (policy-id uint))
    (if (is-eq tx-sender contract-owner)
        (let ((claim (unwrap! (map-get? claims policy-id) err-not-found)))
            (try! (stx-transfer? (get amount claim) contract-owner (get policy-holder claim)))
            (map-set claims policy-id (merge claim { status: "APPROVED" }))
            (ok true)
        )
        err-owner-only
    )
)

;; Reject claim - owner only
(define-public (reject-claim (policy-id uint))
    (if (is-eq tx-sender contract-owner)
        (let ((claim (unwrap! (map-get? claims policy-id) err-not-found)))
            (map-set claims policy-id (merge claim { status: "REJECTED" }))
            (ok true)
        )
        err-owner-only
    )
)

;; Get policy details
(define-read-only (get-policy-details (policy-holder principal))
    (ok (map-get? policies policy-holder))
)

;; Get claim details
(define-read-only (get-claim-details (policy-id uint))
    (ok (map-get? claims policy-id))
)
