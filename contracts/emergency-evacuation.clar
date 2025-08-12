;; Emergency Evacuation System Contract
;; Maintains emergency exits and communication systems in tunnels

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-TUNNEL-NOT-FOUND (err u404))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-SYSTEM-OFFLINE (err u503))

;; Data Variables
(define-data-var next-tunnel-id uint u1)
(define-data-var next-alert-id uint u1)

;; Data Maps
(define-map tunnels
  { tunnel-id: uint }
  {
    name: (string-ascii 50),
    length: uint,
    max-capacity: uint,
    exit-count: uint,
    status: uint,
    created-at: uint
  }
)

(define-map evacuation-systems
  { tunnel-id: uint }
  {
    emergency-exits: uint,
    communication-points: uint,
    evacuation-capacity: uint,
    current-occupancy: uint,
    emergency-active: bool,
    last-drill: uint,
    next-drill: uint,
    system-status: uint
  }
)

(define-map emergency-exits
  { tunnel-id: uint, exit-id: uint }
  {
    exit-name: (string-ascii 30),
    location-meter: uint,
    capacity-per-minute: uint,
    operational: bool,
    last-inspection: uint,
    emergency-lighting: bool
  }
)

(define-map emergency-alerts
  { alert-id: uint }
  {
    tunnel-id: uint,
    alert-type: uint,
    severity: uint,
    message: (string-ascii 200),
    triggered-at: uint,
    resolved-at: uint,
    responder: principal
  }
)

(define-map communication-systems
  { tunnel-id: uint, comm-id: uint }
  {
    comm-type: uint,
    location-meter: uint,
    operational: bool,
    last-tested: uint,
    battery-level: uint
  }
)

(define-map authorized-operators
  { operator: principal }
  { authorized: bool }
)

;; Authorization Functions
(define-private (is-authorized (caller principal))
  (or
    (is-eq caller CONTRACT-OWNER)
    (default-to false (get authorized (map-get? authorized-operators { operator: caller })))
  )
)

;; Public Functions

;; Add authorized operator
(define-public (add-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-operators { operator: operator } { authorized: true }))
  )
)

;; Create new tunnel evacuation system
(define-public (create-tunnel-evacuation (name (string-ascii 50)) (length uint) (max-capacity uint) (exit-count uint))
  (let ((tunnel-id (var-get next-tunnel-id)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> length u0) ERR-INVALID-INPUT)
    (asserts! (> max-capacity u0) ERR-INVALID-INPUT)
    (asserts! (> exit-count u0) ERR-INVALID-INPUT)
    (asserts! (<= exit-count u20) ERR-INVALID-INPUT)

    (map-set tunnels
      { tunnel-id: tunnel-id }
      {
        name: name,
        length: length,
        max-capacity: max-capacity,
        exit-count: exit-count,
        status: u1,
        created-at: block-height
      }
    )

    (map-set evacuation-systems
      { tunnel-id: tunnel-id }
      {
        emergency-exits: exit-count,
        communication-points: (/ length u100),
        evacuation-capacity: (* exit-count u50),
        current-occupancy: u0,
        emergency-active: false,
        last-drill: block-height,
        next-drill: (+ block-height u2160),
        system-status: u1
      }
    )

    (var-set next-tunnel-id (+ tunnel-id u1))
    (ok tunnel-id)
  )
)

;; Create emergency exit
(define-public (create-emergency-exit (tunnel-id uint) (exit-id uint) (exit-name (string-ascii 30)) (location-meter uint) (capacity-per-minute uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? tunnels { tunnel-id: tunnel-id })) ERR-TUNNEL-NOT-FOUND)
    (asserts! (> capacity-per-minute u0) ERR-INVALID-INPUT)

    (map-set emergency-exits
      { tunnel-id: tunnel-id, exit-id: exit-id }
      {
        exit-name: exit-name,
        location-meter: location-meter,
        capacity-per-minute: capacity-per-minute,
        operational: true,
        last-inspection: block-height,
        emergency-lighting: true
      }
    )
    (ok true)
  )
)

;; Trigger emergency alert
(define-public (trigger-emergency-alert (tunnel-id uint) (alert-type uint) (message (string-ascii 200)))
  (let ((alert-id (var-get next-alert-id))
        (system (unwrap! (map-get? evacuation-systems { tunnel-id: tunnel-id }) ERR-TUNNEL-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (>= alert-type u1) ERR-INVALID-INPUT)
    (asserts! (<= alert-type u5) ERR-INVALID-INPUT)

    ;; Determine severity based on alert type
    (let ((severity (if (<= alert-type u2) u3 u2)))
      (map-set emergency-alerts
        { alert-id: alert-id }
        {
          tunnel-id: tunnel-id,
          alert-type: alert-type,
          severity: severity,
          message: message,
          triggered-at: block-height,
          resolved-at: u0,
          responder: tx-sender
        }
      )
    )

    ;; Activate emergency mode
    (map-set evacuation-systems
      { tunnel-id: tunnel-id }
      (merge system {
        emergency-active: true,
        system-status: u3
      })
    )

    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)
  )
)

;; Resolve emergency alert
(define-public (resolve-emergency-alert (alert-id uint))
  (let ((alert (unwrap! (map-get? emergency-alerts { alert-id: alert-id }) ERR-INVALID-INPUT))
        (system (unwrap! (map-get? evacuation-systems { tunnel-id: (get tunnel-id alert) }) ERR-TUNNEL-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get resolved-at alert) u0) ERR-INVALID-INPUT)

    ;; Update alert as resolved
    (map-set emergency-alerts
      { alert-id: alert-id }
      (merge alert {
        resolved-at: block-height,
        responder: tx-sender
      })
    )

    ;; Deactivate emergency mode
    (map-set evacuation-systems
      { tunnel-id: (get tunnel-id alert) }
      (merge system {
        emergency-active: false,
        system-status: u1
      })
    )

    (ok true)
  )
)

;; Update occupancy
(define-public (update-occupancy (tunnel-id uint) (occupancy uint))
  (let ((system (unwrap! (map-get? evacuation-systems { tunnel-id: tunnel-id }) ERR-TUNNEL-NOT-FOUND))
        (tunnel (unwrap! (map-get? tunnels { tunnel-id: tunnel-id }) ERR-TUNNEL-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (<= occupancy (get max-capacity tunnel)) ERR-INVALID-INPUT)

    (map-set evacuation-systems
      { tunnel-id: tunnel-id }
      (merge system { current-occupancy: occupancy })
    )
    (ok true)
  )
)

;; Conduct evacuation drill
(define-public (conduct-evacuation-drill (tunnel-id uint))
  (let ((system (unwrap! (map-get? evacuation-systems { tunnel-id: tunnel-id }) ERR-TUNNEL-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

    (map-set evacuation-systems
      { tunnel-id: tunnel-id }
      (merge system {
        last-drill: block-height,
        next-drill: (+ block-height u2160)
      })
    )
    (ok true)
  )
)

;; Update exit status
(define-public (update-exit-status (tunnel-id uint) (exit-id uint) (operational bool))
  (let ((exit (unwrap! (map-get? emergency-exits { tunnel-id: tunnel-id, exit-id: exit-id }) ERR-INVALID-INPUT)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

    (map-set emergency-exits
      { tunnel-id: tunnel-id, exit-id: exit-id }
      (merge exit {
        operational: operational,
        last-inspection: block-height
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get tunnel info
(define-read-only (get-tunnel (tunnel-id uint))
  (map-get? tunnels { tunnel-id: tunnel-id })
)

;; Get evacuation system status
(define-read-only (get-evacuation-status (tunnel-id uint))
  (map-get? evacuation-systems { tunnel-id: tunnel-id })
)

;; Get emergency exit info
(define-read-only (get-emergency-exit (tunnel-id uint) (exit-id uint))
  (map-get? emergency-exits { tunnel-id: tunnel-id, exit-id: exit-id })
)

;; Get emergency alert
(define-read-only (get-emergency-alert (alert-id uint))
  (map-get? emergency-alerts { alert-id: alert-id })
)

;; Check if evacuation capacity is adequate
(define-read-only (is-evacuation-capacity-adequate (tunnel-id uint))
  (match (map-get? evacuation-systems { tunnel-id: tunnel-id })
    system (>= (get evacuation-capacity system) (get current-occupancy system))
    false
  )
)

;; Check if drill is due
(define-read-only (is-drill-due (tunnel-id uint))
  (match (map-get? evacuation-systems { tunnel-id: tunnel-id })
    system (>= block-height (get next-drill system))
    false
  )
)

;; Calculate evacuation time estimate
(define-read-only (get-evacuation-time-estimate (tunnel-id uint))
  (match (map-get? evacuation-systems { tunnel-id: tunnel-id })
    system (if (> (get evacuation-capacity system) u0)
      (/ (get current-occupancy system) (get evacuation-capacity system))
      u999
    )
    u999
  )
)

;; Get total tunnels
(define-read-only (get-total-tunnels)
  (- (var-get next-tunnel-id) u1)
)
