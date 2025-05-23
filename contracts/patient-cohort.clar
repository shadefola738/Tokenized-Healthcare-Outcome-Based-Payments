;; Patient Cohort Contract
;; Manages treatment groups and patient enrollment

(define-data-var admin principal tx-sender)

;; Map of cohorts
(define-map cohorts
  uint
  {
    name: (string-utf8 100),
    description: (string-utf8 255),
    active: bool,
    created-at: uint,
    provider: principal
  }
)

;; Map of patients in cohorts
(define-map cohort-patients
  { cohort-id: uint, patient-id: (string-utf8 100) }
  {
    enrolled-at: uint,
    active: bool
  }
)

;; Counter for cohort IDs
(define-data-var next-cohort-id uint u1)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-COHORT-NOT-FOUND u101)
(define-constant ERR-PATIENT-ALREADY-ENROLLED u102)
(define-constant ERR-PATIENT-NOT-FOUND u103)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Check if caller is the provider for a cohort
(define-private (is-cohort-provider (cohort-id uint))
  (match (map-get? cohorts cohort-id)
    cohort (is-eq tx-sender (get provider cohort))
    false
  )
)

;; Create a new cohort (only verified providers can do this)
(define-public (create-cohort (name (string-utf8 100)) (description (string-utf8 255)))
  (let ((cohort-id (var-get next-cohort-id)))
    (begin
      ;; Check if provider is verified (would call provider-verification contract in production)
      ;; For simplicity, we're allowing any provider to create cohorts

      (map-set cohorts
        cohort-id
        {
          name: name,
          description: description,
          active: true,
          created-at: block-height,
          provider: tx-sender
        }
      )
      (var-set next-cohort-id (+ cohort-id u1))
      (ok cohort-id)
    )
  )
)

;; Enroll a patient in a cohort
(define-public (enroll-patient (cohort-id uint) (patient-id (string-utf8 100)))
  (begin
    (asserts! (or (is-admin) (is-cohort-provider cohort-id)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some (map-get? cohorts cohort-id)) (err ERR-COHORT-NOT-FOUND))
    (asserts! (is-none (map-get? cohort-patients { cohort-id: cohort-id, patient-id: patient-id }))
              (err ERR-PATIENT-ALREADY-ENROLLED))

    (map-set cohort-patients
      { cohort-id: cohort-id, patient-id: patient-id }
      {
        enrolled-at: block-height,
        active: true
      }
    )
    (ok true)
  )
)

;; Remove a patient from a cohort
(define-public (remove-patient (cohort-id uint) (patient-id (string-utf8 100)))
  (begin
    (asserts! (or (is-admin) (is-cohort-provider cohort-id)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some (map-get? cohort-patients { cohort-id: cohort-id, patient-id: patient-id }))
              (err ERR-PATIENT-NOT-FOUND))

    (map-delete cohort-patients { cohort-id: cohort-id, patient-id: patient-id })
    (ok true)
  )
)

;; Get cohort details
(define-read-only (get-cohort-details (cohort-id uint))
  (map-get? cohorts cohort-id)
)

;; Check if a patient is in a cohort
(define-read-only (is-patient-in-cohort (cohort-id uint) (patient-id (string-utf8 100)))
  (is-some (map-get? cohort-patients { cohort-id: cohort-id, patient-id: patient-id }))
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
