;; Outcome Measurement Contract
;; Tracks health improvements and outcomes

(define-data-var admin principal tx-sender)

;; Map of outcome metrics
(define-map outcome-metrics
  uint
  {
    name: (string-utf8 100),
    description: (string-utf8 255),
    created-at: uint,
    active: bool
  }
)

;; Map of patient outcomes
(define-map patient-outcomes
  { metric-id: uint, cohort-id: uint, patient-id: (string-utf8 100) }
  {
    value: int,
    recorded-at: uint,
    provider: principal
  }
)

;; Counter for metric IDs
(define-data-var next-metric-id uint u1)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-METRIC-NOT-FOUND u101)
(define-constant ERR-COHORT-NOT-FOUND u102)
(define-constant ERR-PATIENT-NOT-FOUND u103)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Create a new outcome metric
(define-public (create-metric (name (string-utf8 100)) (description (string-utf8 255)))
  (let ((metric-id (var-get next-metric-id)))
    (begin
      (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))

      (map-set outcome-metrics
        metric-id
        {
          name: name,
          description: description,
          created-at: block-height,
          active: true
        }
      )
      (var-set next-metric-id (+ metric-id u1))
      (ok metric-id)
    )
  )
)

;; Record a patient outcome
(define-public (record-outcome
                (metric-id uint)
                (cohort-id uint)
                (patient-id (string-utf8 100))
                (value int))
  (begin
    ;; In production, we would check if provider is verified and if patient is in cohort
    ;; For simplicity, we're allowing any provider to record outcomes

    (asserts! (is-some (map-get? outcome-metrics metric-id)) (err ERR-METRIC-NOT-FOUND))

    (map-set patient-outcomes
      { metric-id: metric-id, cohort-id: cohort-id, patient-id: patient-id }
      {
        value: value,
        recorded-at: block-height,
        provider: tx-sender
      }
    )
    (ok true)
  )
)

;; Get outcome metric details
(define-read-only (get-metric-details (metric-id uint))
  (map-get? outcome-metrics metric-id)
)

;; Get patient outcome
(define-read-only (get-patient-outcome (metric-id uint) (cohort-id uint) (patient-id (string-utf8 100)))
  (map-get? patient-outcomes { metric-id: metric-id, cohort-id: cohort-id, patient-id: patient-id })
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
