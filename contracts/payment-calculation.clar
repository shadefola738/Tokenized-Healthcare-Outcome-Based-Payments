;; Payment Calculation Contract
;; Determines outcome-based compensation

(define-data-var admin principal tx-sender)

;; Define the payment token
(define-fungible-token healthcare-payment)

;; Map of payment models
(define-map payment-models
  uint
  {
    name: (string-utf8 100),
    description: (string-utf8 255),
    base-amount: uint,
    outcome-bonus-percent: uint,
    risk-adjustment-factor: uint,
    created-at: uint,
    active: bool
  }
)

;; Map of payments made
(define-map payments
  uint
  {
    provider: principal,
    cohort-id: uint,
    model-id: uint,
    amount: uint,
    paid-at: uint
  }
)

;; Counter for payment model IDs
(define-data-var next-model-id uint u1)

;; Counter for payment IDs
(define-data-var next-payment-id uint u1)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-MODEL-NOT-FOUND u101)
(define-constant ERR-COHORT-NOT-FOUND u102)
(define-constant ERR-INSUFFICIENT-FUNDS u103)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Create a new payment model
(define-public (create-payment-model
                (name (string-utf8 100))
                (description (string-utf8 255))
                (base-amount uint)
                (outcome-bonus-percent uint)
                (risk-adjustment-factor uint))
  (let ((model-id (var-get next-model-id)))
    (begin
      (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))

      (map-set payment-models
        model-id
        {
          name: name,
          description: description,
          base-amount: base-amount,
          outcome-bonus-percent: outcome-bonus-percent,
          risk-adjustment-factor: risk-adjustment-factor,
          created-at: block-height,
          active: true
        }
      )
      (var-set next-model-id (+ model-id u1))
      (ok model-id)
    )
  )
)

;; Calculate payment amount based on outcomes and risk
;; In a real implementation, this would query the outcome and risk contracts
(define-private (calculate-payment-amount (model-id uint) (cohort-id uint))
  (match (map-get? payment-models model-id)
    model (ok (get base-amount model))
    (err ERR-MODEL-NOT-FOUND)
  )
)

;; Make a payment to a provider
(define-public (make-payment (provider principal) (model-id uint) (cohort-id uint))
  (let (
    (payment-id (var-get next-payment-id))
    (payment-result (calculate-payment-amount model-id cohort-id))
  )
    (match payment-result
      payment-amount (begin
        ;; Mint tokens to the provider
        (try! (ft-mint? healthcare-payment payment-amount provider))

        ;; Record the payment
        (map-set payments
          payment-id
          {
            provider: provider,
            cohort-id: cohort-id,
            model-id: model-id,
            amount: payment-amount,
            paid-at: block-height
          }
        )
        (var-set next-payment-id (+ payment-id u1))
        (ok payment-id)
      )
      error (err error)
    )
  )
)

;; Get payment model details
(define-read-only (get-payment-model-details (model-id uint))
  (map-get? payment-models model-id)
)

;; Get payment details
(define-read-only (get-payment-details (payment-id uint))
  (map-get? payments payment-id)
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
