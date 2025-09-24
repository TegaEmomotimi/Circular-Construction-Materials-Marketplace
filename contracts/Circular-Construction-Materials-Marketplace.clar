(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-not-authorized (err u104))
(define-constant err-material-not-available (err u105))
(define-constant err-invalid-value (err u106))

(define-data-var next-material-id uint u1)
(define-data-var platform-fee-percentage uint u5)
(define-data-var next-listing-id uint u1)
(define-data-var next-transaction-id uint u1)
(define-data-var total-platform-revenue uint u0)
(define-data-var next-auction-id uint u1)

(define-map material-passports
  { material-id: uint }
  {
    owner: principal,
    material-type: (string-ascii 50),
    origin-project: (string-ascii 100),
    quality-grade: (string-ascii 10),
    quantity: uint,
    co2-footprint: uint,
    location: (string-ascii 100),
    created-at: uint,
    is-available: bool,
    price-per-unit: uint
  }
)

(define-map material-listings
  { listing-id: uint }
  {
    seller: principal,
    material-id: uint,
    quantity-available: uint,
    price-per-unit: uint,
    is-active: bool,
    created-at: uint
  }
)

(define-map material-transactions
  { transaction-id: uint }
  {
    buyer: principal,
    seller: principal,
    material-id: uint,
    quantity: uint,
    total-price: uint,
    transaction-date: uint,
    co2-saved: uint
  }
)

(define-map user-profiles
  { user: principal }
  {
    total-materials-listed: uint,
    total-materials-purchased: uint,
    total-co2-saved: uint,
    reputation-score: uint
  }
)

(define-map material-auctions
  { auction-id: uint }
  {
    seller: principal,
    material-id: uint,
    starting-price: uint,
    current-bid: uint,
    current-bidder: principal,
    end-block: uint,
    is-active: bool
  }
)

(define-public (create-material-passport
  (material-type (string-ascii 50))
  (origin-project (string-ascii 100))
  (quality-grade (string-ascii 10))
  (quantity uint)
  (co2-footprint uint)
  (location (string-ascii 100))
  (price-per-unit uint))
  (let ((material-id (var-get next-material-id)))
    (asserts! (> co2-footprint u0) err-invalid-value)
    (asserts! (> quantity u0) err-insufficient-funds)
    (asserts! (> price-per-unit u0) err-invalid-value)
    (map-set material-passports
      { material-id: material-id }
      {
        owner: tx-sender,
        material-type: material-type,
        origin-project: origin-project,
        quality-grade: quality-grade,
        quantity: quantity,
        co2-footprint: co2-footprint,
        location: location,
        created-at: stacks-block-height,
        is-available: true,
        price-per-unit: price-per-unit
      }
    )
    (var-set next-material-id (+ material-id u1))
    (ok material-id)
  )
)

(define-public (list-material-for-sale
  (material-id uint)
  (quantity-to-sell uint)
  (price-per-unit uint))
  (let ((material (unwrap! (map-get? material-passports { material-id: material-id }) err-not-found))
        (listing-id (var-get next-listing-id)))
    (asserts! (is-eq (get owner material) tx-sender) err-not-authorized)
    (asserts! (get is-available material) err-material-not-available)
    (asserts! (<= quantity-to-sell (get quantity material)) err-insufficient-funds)
    (asserts! (> price-per-unit u0) err-invalid-value)
    (map-set material-listings
      { listing-id: listing-id }
      {
        seller: tx-sender,
        material-id: material-id,
        quantity-available: quantity-to-sell,
        price-per-unit: price-per-unit,
        is-active: true,
        created-at: stacks-block-height
      }
    )
    (var-set next-listing-id (+ listing-id u1))
    (update-user-materials-listed tx-sender)
    (ok listing-id)
  )
)

(define-public (purchase-material
  (listing-id uint)
  (quantity-to-buy uint))
  (let ((listing (unwrap! (map-get? material-listings { listing-id: listing-id }) err-not-found))
        (material-id (get material-id listing))
        (material (unwrap! (map-get? material-passports { material-id: material-id }) err-not-found))
        (total-price (* (get price-per-unit listing) quantity-to-buy))
        (platform-fee (/ (* total-price (var-get platform-fee-percentage)) u100))
        (seller-amount (- total-price platform-fee))
        (transaction-id (var-get next-transaction-id))
        (co2-saved (/ (* (get co2-footprint material) quantity-to-buy) (get quantity material))))
    (asserts! (get is-active listing) err-material-not-available)
    (asserts! (<= quantity-to-buy (get quantity-available listing)) err-insufficient-funds)
    (asserts! (>= (stx-get-balance tx-sender) total-price) err-insufficient-funds)
    (asserts! (> quantity-to-buy u0) err-invalid-value)
    
    (try! (stx-transfer? seller-amount tx-sender (get seller listing)))
    (try! (stx-transfer? platform-fee tx-sender contract-owner))
    
    (map-set material-transactions
      { transaction-id: transaction-id }
      {
        buyer: tx-sender,
        seller: (get seller listing),
        material-id: material-id,
        quantity: quantity-to-buy,
        total-price: total-price,
        transaction-date: stacks-block-height,
        co2-saved: co2-saved
      }
    )
    
    (if (is-eq quantity-to-buy (get quantity-available listing))
      (map-set material-listings
        { listing-id: listing-id }
        (merge listing { is-active: false, quantity-available: u0 }))
      (map-set material-listings
        { listing-id: listing-id }
        (merge listing { quantity-available: (- (get quantity-available listing) quantity-to-buy) }))
    )
    
    (map-set material-passports
      { material-id: material-id }
      (merge material { owner: tx-sender, quantity: (- (get quantity material) quantity-to-buy) })
    )
    
    (if (is-eq (get quantity material) quantity-to-buy)
      (map-set material-passports
        { material-id: material-id }
        (merge material { is-available: false }))
      true
    )
    
    (var-set next-transaction-id (+ transaction-id u1))
    (var-set total-platform-revenue (+ (var-get total-platform-revenue) platform-fee))
    (update-user-materials-purchased tx-sender co2-saved)
    (ok transaction-id)
  )
)

(define-private (update-user-materials-listed
  (user principal))
  (let ((current-profile (default-to
          { total-materials-listed: u0, total-materials-purchased: u0, total-co2-saved: u0, reputation-score: u0 }
          (map-get? user-profiles { user: user }))))
    (map-set user-profiles
      { user: user }
      {
        total-materials-listed: (+ (get total-materials-listed current-profile) u1),
        total-materials-purchased: (get total-materials-purchased current-profile),
        total-co2-saved: (get total-co2-saved current-profile),
        reputation-score: (calculate-reputation-score 
          (+ (get total-materials-listed current-profile) u1)
          (get total-materials-purchased current-profile)
          (get total-co2-saved current-profile))
      }
    )
  )
)

(define-private (update-user-materials-purchased
  (user principal)
  (co2-saved uint))
  (let ((current-profile (default-to
          { total-materials-listed: u0, total-materials-purchased: u0, total-co2-saved: u0, reputation-score: u0 }
          (map-get? user-profiles { user: user }))))
    (map-set user-profiles
      { user: user }
      {
        total-materials-listed: (get total-materials-listed current-profile),
        total-materials-purchased: (+ (get total-materials-purchased current-profile) u1),
        total-co2-saved: (+ (get total-co2-saved current-profile) co2-saved),
        reputation-score: (calculate-reputation-score 
          (get total-materials-listed current-profile)
          (+ (get total-materials-purchased current-profile) u1)
          (+ (get total-co2-saved current-profile) co2-saved))
      }
    )
  )
)

(define-private (calculate-reputation-score
  (materials-listed uint)
  (materials-purchased uint)
  (co2-saved uint))
  (+ (* materials-listed u10) (* materials-purchased u5) (/ co2-saved u100))
)

(define-public (update-material-availability
  (material-id uint)
  (is-available bool))
  (let ((material (unwrap! (map-get? material-passports { material-id: material-id }) err-not-found)))
    (asserts! (is-eq (get owner material) tx-sender) err-not-authorized)
    (map-set material-passports
      { material-id: material-id }
      (merge material { is-available: is-available })
    )
    (ok true)
  )
)

(define-public (cancel-listing
  (listing-id uint))
  (let ((listing (unwrap! (map-get? material-listings { listing-id: listing-id }) err-not-found)))
    (asserts! (is-eq (get seller listing) tx-sender) err-not-authorized)
    (asserts! (get is-active listing) err-material-not-available)
    (map-set material-listings
      { listing-id: listing-id }
      (merge listing { is-active: false })
    )
    (ok true)
  )
)

(define-public (update-platform-fee
  (new-fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee-percentage u20) err-invalid-value)
    (var-set platform-fee-percentage new-fee-percentage)
    (ok true)
  )
)

(define-read-only (get-material-passport
  (material-id uint))
  (map-get? material-passports { material-id: material-id })
)

(define-read-only (get-material-listing
  (listing-id uint))
  (map-get? material-listings { listing-id: listing-id })
)

(define-read-only (get-transaction
  (transaction-id uint))
  (map-get? material-transactions { transaction-id: transaction-id })
)

(define-read-only (get-user-profile
  (user principal))
  (map-get? user-profiles { user: user })
)

(define-read-only (get-platform-stats)
  {
    total-materials: (- (var-get next-material-id) u1),
    total-listings: (- (var-get next-listing-id) u1),
    total-transactions: (- (var-get next-transaction-id) u1),
    platform-revenue: (var-get total-platform-revenue),
    platform-fee-percentage: (var-get platform-fee-percentage)
  }
)

(define-read-only (calculate-co2-impact
  (material-id uint)
  (quantity uint))
  (let ((material (unwrap! (map-get? material-passports { material-id: material-id }) err-not-found)))
    (ok (/ (* (get co2-footprint material) quantity) (get quantity material)))
  )
)

(define-public (transfer-material-ownership
  (material-id uint)
  (new-owner principal))
  (let ((material (unwrap! (map-get? material-passports { material-id: material-id }) err-not-found)))
    (asserts! (is-eq (get owner material) tx-sender) err-not-authorized)
    (map-set material-passports
      { material-id: material-id }
      (merge material { owner: new-owner })
    )
    (ok true)
  )
)

(define-read-only (get-active-listings)
  (fold check-active-listing (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) (list))
)

(define-private (check-active-listing
  (listing-id uint)
  (accumulator (list 20 uint)))
  (let ((listing (map-get? material-listings { listing-id: listing-id })))
    (match listing
      active-listing (if (get is-active active-listing)
                       (unwrap-panic (as-max-len? (append accumulator listing-id) u20))
                       accumulator)
      accumulator
    )
  )
)

(define-read-only (get-user-materials
  (user principal))
  (fold check-user-materials (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) (list))
)

(define-private (check-user-materials
  (material-id uint)
  (accumulator (list 20 uint)))
  (let ((material (map-get? material-passports { material-id: material-id })))
    (match material
      passport (if (is-eq (get owner passport) tx-sender)
                 (unwrap-panic (as-max-len? (append accumulator material-id) u20))
                 accumulator)
      accumulator
    )
  )
)

(define-read-only (get-available-materials)
  (fold check-available-materials (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) (list))
)

(define-private (check-available-materials
  (material-id uint)
  (accumulator (list 20 uint)))
  (let ((material (map-get? material-passports { material-id: material-id })))
    (match material
      passport (if (and (get is-available passport) (> (get quantity passport) u0))
                 (unwrap-panic (as-max-len? (append accumulator material-id) u20))
                 accumulator)
      accumulator
    )
  )
)

(define-public (withdraw-platform-revenue)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((revenue (var-get total-platform-revenue)))
      (var-set total-platform-revenue u0)
      (try! (stx-transfer? revenue (as-contract tx-sender) tx-sender))
      (ok revenue)
    )
  )
)

(define-read-only (get-total-co2-saved)
  (fold sum-co2-transactions (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) u0)
)

(define-private (sum-co2-transactions
  (transaction-id uint)
  (accumulator uint))
  (let ((transaction (map-get? material-transactions { transaction-id: transaction-id })))
    (match transaction
      tx-data (+ accumulator (get co2-saved tx-data))
      accumulator
    )
  )
)

(define-read-only (verify-material-authenticity
  (material-id uint))
  (let ((material (map-get? material-passports { material-id: material-id })))
    (match material
      passport {
        exists: true,
        created-at: (get created-at passport),
        owner: (get owner passport),
        co2-footprint: (get co2-footprint passport)
      }
      { exists: false, created-at: u0, owner: contract-owner, co2-footprint: u0 }
    )
  )
)

(define-public (rate-transaction
  (transaction-id uint)
  (rating uint))
  (let ((transaction (unwrap! (map-get? material-transactions { transaction-id: transaction-id }) err-not-found)))
    (asserts! (or (is-eq tx-sender (get buyer transaction)) (is-eq tx-sender (get seller transaction))) err-not-authorized)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-value)
    (ok true)
  )
)

(define-read-only (get-marketplace-summary)
  {
    total-materials: (- (var-get next-material-id) u1),
    active-listings: (len (get-active-listings)),
    total-transactions: (- (var-get next-transaction-id) u1),
    total-co2-saved: (get-total-co2-saved),
    platform-fee: (var-get platform-fee-percentage)
  }
)

(define-read-only (is-material-available-by-id
  (material-id uint))
  (let ((material (map-get? material-passports { material-id: material-id })))
    (match material
      passport (and (get is-available passport) (> (get quantity passport) u0))
      false
    )
  )
)

(define-read-only (get-co2-savings-by-user
  (user principal))
  (let ((profile (map-get? user-profiles { user: user })))
    (match profile
      user-data (get total-co2-saved user-data)
      u0
    )
  )
)

(define-private (validate-purchase
  (purchase {listing-id: uint, quantity: uint}))
  (let ((listing (map-get? material-listings { listing-id: (get listing-id purchase) })))
    (match listing
      lst (and (get is-active lst) (<= (get quantity purchase) (get quantity-available lst)) (> (get quantity purchase) u0))
      false
    )
  )
)

(define-private (calculate-batch-cost
  (purchase {listing-id: uint, quantity: uint})
  (accumulator uint))
  (let ((listing (unwrap-panic (map-get? material-listings { listing-id: (get listing-id purchase) })))
        (quantity-to-buy (get quantity purchase)))
    (+ accumulator (* (get price-per-unit listing) quantity-to-buy))))

(define-private (process-batch-purchase
  (purchase {listing-id: uint, quantity: uint})
  (accumulator {transaction-ids: (list 10 uint), transfers: (list 10 {seller: principal, amount: uint}), total-platform: uint, co2-total: uint}))
  (let ((listing (unwrap-panic (map-get? material-listings { listing-id: (get listing-id purchase) })))
        (material-id (get material-id listing))
        (material (unwrap-panic (map-get? material-passports { material-id: material-id })))
        (quantity-to-buy (get quantity purchase))
        (total-price (* (get price-per-unit listing) quantity-to-buy))
        (platform-fee (/ (* total-price (var-get platform-fee-percentage)) u100))
        (seller-amount (- total-price platform-fee))
        (transaction-id (var-get next-transaction-id))
        (co2-saved (/ (* (get co2-footprint material) quantity-to-buy) (get quantity material))))
    (map-set material-transactions
      { transaction-id: transaction-id }
      {
        buyer: tx-sender,
        seller: (get seller listing),
        material-id: material-id,
        quantity: quantity-to-buy,
        total-price: total-price,
        transaction-date: stacks-block-height,
        co2-saved: co2-saved
      }
    )
    (if (is-eq quantity-to-buy (get quantity-available listing))
      (map-set material-listings
        { listing-id: (get listing-id purchase) }
        (merge listing { is-active: false, quantity-available: u0 }))
      (map-set material-listings
        { listing-id: (get listing-id purchase) }
        (merge listing { quantity-available: (- (get quantity-available listing) quantity-to-buy) }))
    )
    (map-set material-passports
      { material-id: material-id }
      (merge material { owner: tx-sender, quantity: (- (get quantity material) quantity-to-buy) })
    )
    (if (is-eq (get quantity material) quantity-to-buy)
      (map-set material-passports
        { material-id: material-id }
        (merge material { is-available: false }))
      true
    )
    (var-set next-transaction-id (+ transaction-id u1))
    (update-user-materials-purchased tx-sender co2-saved)
    {
      transaction-ids: (unwrap-panic (as-max-len? (append (get transaction-ids accumulator) transaction-id) u10)),
      transfers: (unwrap-panic (as-max-len? (append (get transfers accumulator) {seller: (get seller listing), amount: seller-amount}) u10)),
      total-platform: (+ (get total-platform accumulator) platform-fee),
      co2-total: (+ (get co2-total accumulator) co2-saved)
    }
  )
)

(define-private (execute-transfer
  (transfer {seller: principal, amount: uint}))
  (stx-transfer? (get amount transfer) tx-sender (get seller transfer))
)

(define-private (execute-transfer-fold
  (transfer {seller: principal, amount: uint})
  (acc bool))
  (begin
    (unwrap-panic (execute-transfer transfer))
    true
  )
)

(define-public (batch-purchase
  (purchases (list 10 {listing-id: uint, quantity: uint})))
  (begin
    (asserts! (is-eq (len (filter validate-purchase purchases)) (len purchases)) err-invalid-value)
    (let ((total-cost (fold calculate-batch-cost purchases u0)))
      (asserts! (>= (stx-get-balance tx-sender) total-cost) err-insufficient-funds)
      (let ((result (fold process-batch-purchase purchases {transaction-ids: (list), transfers: (list), total-platform: u0, co2-total: u0})))
        (fold execute-transfer-fold (get transfers result) true)
        (unwrap-panic (stx-transfer? (get total-platform result) tx-sender contract-owner))
        (var-set total-platform-revenue (+ (var-get total-platform-revenue) (get total-platform result)))
        (ok (get transaction-ids result))
      )
    )
  )
)

(define-public (create-auction
  (material-id uint)
  (starting-price uint)
  (duration-blocks uint))
  (let ((material (unwrap! (map-get? material-passports { material-id: material-id }) err-not-found))
        (auction-id (var-get next-auction-id)))
    (asserts! (is-eq (get owner material) tx-sender) err-not-authorized)
    (asserts! (get is-available material) err-material-not-available)
    (asserts! (> starting-price u0) err-invalid-value)
    (asserts! (> duration-blocks u0) err-invalid-value)
    (map-set material-auctions
      { auction-id: auction-id }
      {
        seller: tx-sender,
        material-id: material-id,
        starting-price: starting-price,
        current-bid: u0,
        current-bidder: contract-owner,
        end-block: (+ stacks-block-height duration-blocks),
        is-active: true
      }
    )
    (var-set next-auction-id (+ auction-id u1))
    (ok auction-id)
  )
)

(define-public (place-bid
  (auction-id uint)
  (bid-amount uint))
  (let ((auction (unwrap! (map-get? material-auctions { auction-id: auction-id }) err-not-found)))
    (asserts! (get is-active auction) err-material-not-available)
    (asserts! (> bid-amount (get current-bid auction)) err-invalid-value)
    (asserts! (>= (stx-get-balance tx-sender) bid-amount) err-insufficient-funds)
    (asserts! (< stacks-block-height (get end-block auction)) err-invalid-value)
    (map-set material-auctions
      { auction-id: auction-id }
      (merge auction { current-bid: bid-amount, current-bidder: tx-sender })
    )
    (ok true)
  )
)

(define-public (end-auction
  (auction-id uint))
  (let ((auction (unwrap! (map-get? material-auctions { auction-id: auction-id }) err-not-found))
        (material-id (get material-id auction))
        (material (unwrap! (map-get? material-passports { material-id: material-id }) err-not-found))
        (bidder (get current-bidder auction))
        (bid-amount (get current-bid auction)))
    (asserts! (get is-active auction) err-material-not-available)
    (asserts! (>= stacks-block-height (get end-block auction)) err-invalid-value)
    (asserts! (> bid-amount u0) err-invalid-value)
    (try! (stx-transfer? bid-amount bidder (get seller auction)))
    (map-set material-passports
      { material-id: material-id }
      (merge material { owner: bidder })
    )
    (map-set material-auctions
      { auction-id: auction-id }
      (merge auction { is-active: false })
    )
    (ok true)
  )
)

(define-read-only (get-auction
  (auction-id uint))
  (map-get? material-auctions { auction-id: auction-id })
)
