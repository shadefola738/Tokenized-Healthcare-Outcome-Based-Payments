;; Risk Adjustment Contract
;; Accounts for patient complexity in outcome measurements

(define-data-var admin principal tx-sender)

;; Map of risk factors
(define-map risk-factors
  uint
  {
    name: (string-utf8 100),
    description: (string-utf8 255),
    weight: uint,
    created-at: uint,
    active: bool
  }
)

;; Map of patient risk scores
(define-map patient-risk-scores
  { cohort-id: uint, patient-id: (string-utf8 100) }
  {
    score: uint,
    calculated-at: uint,
    provider: principal
  }
)

;; Map of patient risk factors
(define-map patient-risk-factors
  { factor-id: uint, cohort-id: uint, patient-id: (string-utf8 100) }
  {
    present: bool,
    recorded-at: uint,
    provider: principal
  }
)

;; Counter for risk factor IDs
(define-data-var next-factor-id uint u1)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-FACTOR-NOT-FOUND u101)
(define-constant ERR-COHORT-NOT-FOUND u102)
(define-constant ERR-PATIENT-NOT-FOUND u103)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Create a new risk factor
(define-public (create-risk-factor (name (string-utf8 100)) (description (string-utf8 255)) (weight uint))
  (let ((factor-id (var-get next-factor-id)))
    (begin
      (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))

      (map-set risk-factors
        factor-id
        {
          name: name,
          description: description,
          weight: weight,
          created-at: block-height,
          active: true
        }
      )
      (var-set next-factor-id (+ factor-id u1))
      (ok factor-id)
    )
  )
)

;; Record a patient risk factor
(define-public (record-patient-risk-factor
                (factor-id uint)
                (cohort-id uint)
                (patient-id (string-utf8 100))
                (present bool))
  (begin
    ;; In production, we would check if provider is verified and if patient is in cohort
    ;; For simplicity, we're allowing any provider to record risk factors

    (asserts! (is-some (map-get? risk-factors factor-id)) (err ERR-FACTOR-NOT-FOUND))

    (map-set patient-risk-factors
      { factor-id: factor-id, cohort-id: cohort-id, patient-id: patient-id }
      {
        present: present,
        recorded-at: block-height,
        provider: tx-sender
      }
    )
    (ok true)
  )
)

;; Calculate and record a patient's risk score
(define-public (calculate-risk-score (cohort-id uint) (patient-id (string-utf8 100)))
  (begin
    ;; In a real implementation, this would calculate based on all risk factors
    ;; For simplicity, we're just setting a placeholder value

    (map-set patient-risk-scores
      { cohort-id: cohort-id, patient-id: patient-id }
      {
        score: u100, ;; Placeholder score
        calculated-at: block-height,
        provider: tx-sender
      }
    )
    (ok true)
  )
)

;; Get risk factor details
(define-read-only (get-risk-factor-details (factor-id uint))
  (map-get? risk-factors factor-id)
)

;; Get patient risk score
(define-read-only (get-patient-risk-score (cohort-id uint) (patient-id (string-utf8 100)))
  (map-get? patient-risk-scores { cohort-id: cohort-id, patient-id: patient-id })
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
