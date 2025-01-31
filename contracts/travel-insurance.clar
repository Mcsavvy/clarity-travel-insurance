;; Travel Insurance Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-not-active (err u103))
(define-constant err-already-claimed (err u104))
(define-constant err-refund-window-expired (err u105))
(define-constant err-invalid-policy (err u106))

;; Data Variables  
(define-data-var insurance-fee uint u100)
(define-data-var claim-period uint u30) ;; in days
(define-data-var refund-window uint u48) ;; in hours
(define-data-var next-policy-id uint u0)

;; Data Maps
(define-map policies
    uint 
    {
        policy-holder: principal,
        start-date: uint,
        end-date: uint,
        destination: (string-ascii 50),
        premium-paid: uint,
        is-active: bool,
        is-claimed: bool,
        creation-height: uint
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

(define-map user-policies
    principal
    (list 20 uint)
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

;; Get next policy ID and increment
(define-private (get-and-increment-policy-id)
    (let ((current-id (var-get next-policy-id)))
        (var-set next-policy-id (+ current-id u1))
        current-id
    )
)

;; Add policy ID to user's policy list
(define-private (add-user-policy (user principal) (policy-id uint))
    (let ((existing-policies (default-to (list) (map-get? user-policies user))))
        (map-set user-policies user (append existing-policies policy-id))
    )
)

;; Purchase insurance policy
(define-public (purchase-policy 
    (start-date uint)
    (end-date uint)
    (destination (string-ascii 50)))
    
    (let ((policy-id (get-and-increment-policy-id)))
        (begin
            (try! (stx-transfer? (var-get insurance-fee) tx-sender contract-owner))
            (add-user-policy tx-sender policy-id)
            (ok (map-set policies policy-id {
                policy-holder: tx-sender,
                start-date: start-date,
                end-date: end-date,
                destination: destination,
                premium-paid: (var-get insurance-fee),
                is-active: true,
                is-claimed: false,
                creation-height: block-height
            }))
        )
    )
)

;; Request refund
(define-public (request-refund (policy-id uint))
    (let ((policy (unwrap! (map-get? policies policy-id) err-not-found)))
        (asserts! (is-eq (get policy-holder policy) tx-sender) err-owner-only)
        (asserts! (get is-active policy) err-not-active)
        (asserts! (not (get is-claimed policy)) err-already-claimed)
        (asserts! (<= (- block-height (get creation-height policy)) (var-get refund-window)) err-refund-window-expired)
        (begin
            (try! (stx-transfer? (/ (get premium-paid policy) u2) contract-owner tx-sender))
            (ok (map-set policies policy-id (merge policy { is-active: false })))
        )
    )
)

;; File an insurance claim
(define-public (file-claim 
    (policy-id uint)
    (reason (string-ascii 100))
    (amount uint))
    
    (let ((policy (unwrap! (map-get? policies policy-id) err-not-found)))
        (asserts! (is-eq (get policy-holder policy) tx-sender) err-invalid-policy)
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
        (let ((claim (unwrap! (map-get? claims policy-id) err-not-found))
              (policy (unwrap! (map-get? policies policy-id) err-not-found)))
            (begin 
                (try! (stx-transfer? (get amount claim) contract-owner (get policy-holder claim)))
                (map-set claims policy-id (merge claim { status: "APPROVED" }))
                (map-set policies policy-id (merge policy { is-claimed: true }))
                (ok true)
            )
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
(define-read-only (get-policy-details (policy-id uint))
    (ok (map-get? policies policy-id))
)

;; Get claim details
(define-read-only (get-claim-details (policy-id uint))
    (ok (map-get? claims policy-id))
)

;; Get all policies for a user
(define-read-only (get-user-policies (user principal))
    (ok (map-get? user-policies user))
)
