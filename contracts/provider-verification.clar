;; Provider Verification Contract
;; Validates healthcare entities and their credentials

(define-data-var admin principal tx-sender)

;; Map of verified providers
(define-map providers
  principal
  {
    name: (string-utf8 100),
    specialty: (string-utf8 100),
    verified: bool,
    verification-date: uint
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-ALREADY-VERIFIED u101)
(define-constant ERR-NOT-FOUND u102)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new provider (only admin can do this)
(define-public (register-provider (provider-address principal) (name (string-utf8 100)) (specialty (string-utf8 100)))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none (map-get? providers provider-address)) (err ERR-ALREADY-VERIFIED))

    (map-set providers
      provider-address
      {
        name: name,
        specialty: specialty,
        verified: true,
        verification-date: block-height
      }
    )
    (ok true)
  )
)

;; Revoke provider verification
(define-public (revoke-provider (provider-address principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some (map-get? providers provider-address)) (err ERR-NOT-FOUND))

    (map-delete providers provider-address)
    (ok true)
  )
)

;; Check if a provider is verified
(define-read-only (is-verified-provider (provider-address principal))
  (match (map-get? providers provider-address)
    provider (ok (get verified provider))
    (err ERR-NOT-FOUND)
  )
)

;; Get provider details
(define-read-only (get-provider-details (provider-address principal))
  (map-get? providers provider-address)
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
