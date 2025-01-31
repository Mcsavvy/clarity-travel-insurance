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
(define-constant err-invalid-dates (err u107))

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

;; Validate policy dates
(define-private (validate-dates (start-date uint) (end-date uint))
    (and 
        (> start-date block-height)
        (> end-date start-date)
        (<= (- end-date start-date) u365) ;; Max 1 year policy
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
    
    (begin
        (asserts! (validate-dates start-date end-date) err-invalid-dates)
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
)

;; [Rest of contract remains unchanged]
