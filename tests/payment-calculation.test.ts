import { describe, it, expect, beforeEach } from "vitest"

// Mock implementation for testing Clarity contracts

// Mock state
const mockPaymentModels = new Map()
const mockPayments = new Map()
const mockTokenBalances = new Map()
let mockAdmin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM" // Example principal
let mockTxSender = mockAdmin
let mockNextModelId = 1
let mockNextPaymentId = 1

// Mock fungible token functions
const ftMint = (amount, recipient) => {
  const currentBalance = mockTokenBalances.get(recipient) || 0
  mockTokenBalances.set(recipient, currentBalance + amount)
  return { type: "ok", value: true }
}

// Mock contract functions
const paymentCalculation = {
  createPaymentModel: (name, description, baseAmount, outcomeBonusPercent, riskAdjustmentFactor) => {
    if (mockTxSender !== mockAdmin) {
      return { type: "err", value: 100 } // ERR-NOT-AUTHORIZED
    }
    
    const modelId = mockNextModelId
    
    mockPaymentModels.set(modelId, {
      name,
      description,
      baseAmount,
      outcomeBonusPercent,
      riskAdjustmentFactor,
      createdAt: 123, // Mock block height
      active: true,
    })
    
    mockNextModelId++
    return { type: "ok", value: modelId }
  },
  
  calculatePaymentAmount: (modelId, cohortId) => {
    if (!mockPaymentModels.has(modelId)) {
      return { type: "err", value: 101 } // ERR-MODEL-NOT-FOUND
    }
    
    const model = mockPaymentModels.get(modelId)
    return { type: "ok", value: model.baseAmount }
  },
  
  makePayment: (provider, modelId, cohortId) => {
    if (!mockPaymentModels.has(modelId)) {
      return { type: "err", value: 101 } // ERR-MODEL-NOT-FOUND
    }
    
    const model = mockPaymentModels.get(modelId)
    const paymentAmount = model.baseAmount
    
    // Mint tokens to provider
    ftMint(paymentAmount, provider)
    
    const paymentId = mockNextPaymentId
    
    mockPayments.set(paymentId, {
      provider,
      cohortId,
      modelId,
      amount: paymentAmount,
      paidAt: 123, // Mock block height
    })
    
    mockNextPaymentId++
    return { type: "ok", value: paymentId }
  },
  
  getPaymentModelDetails: (modelId) => {
    return mockPaymentModels.get(modelId) || null
  },
  
  getPaymentDetails: (paymentId) => {
    return mockPayments.get(paymentId) || null
  },
  
  transferAdmin: (newAdmin) => {
    if (mockTxSender !== mockAdmin) {
      return { type: "err", value: 100 } // ERR-NOT-AUTHORIZED
    }
    
    mockAdmin = newAdmin
    return { type: "ok", value: true }
  },
}

// Tests
describe("Payment Calculation Contract", () => {
  beforeEach(() => {
    // Reset state before each test
    mockPaymentModels.clear()
    mockPayments.clear()
    mockTokenBalances.clear()
    mockAdmin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
    mockTxSender = mockAdmin
    mockNextModelId = 1
    mockNextPaymentId = 1
  })
  
  it("should create a new payment model", () => {
    const result = paymentCalculation.createPaymentModel(
        "Diabetes Care",
        "Payment model for diabetes management",
        1000, // base amount
        10, // outcome bonus percent
        5, // risk adjustment factor
    )
    
    expect(result.type).toBe("ok")
    expect(result.value).toBe(1)
    
    const model = mockPaymentModels.get(1)
    expect(model).toBeDefined()
    expect(model.name).toBe("Diabetes Care")
    expect(model.description).toBe("Payment model for diabetes management")
    expect(model.baseAmount).toBe(1000)
    expect(model.outcomeBonusPercent).toBe(10)
    expect(model.riskAdjustmentFactor).toBe(5)
    expect(model.active).toBe(true)
  })
  
  it("should not allow non-admin to create payment models", () => {
    mockTxSender = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG" // Different sender
    
    const result = paymentCalculation.createPaymentModel(
        "Diabetes Care",
        "Payment model for diabetes management",
        1000, // base amount
        10, // outcome bonus percent
        5, // risk adjustment factor
    )
    
    expect(result.type).toBe("err")
    expect(result.value).toBe(100) // ERR-NOT-AUTHORIZED
  })
  
  it("should make a payment to a provider", () => {
    // Create payment model first
    const createResult = paymentCalculation.createPaymentModel(
        "Diabetes Care",
        "Payment model for diabetes management",
        1000, // base amount
        10, // outcome bonus percent
        5, // risk adjustment factor
    )
    const modelId = createResult.value
    
    const providerAddress = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
    
    // Make payment
    const paymentResult = paymentCalculation.makePayment(
        providerAddress,
        modelId,
        1, // cohort ID
    )
    
    expect(paymentResult.type).toBe("ok")
    expect(paymentResult.value).toBe(1) // payment ID
    
    // Check payment record
    const payment = mockPayments.get(1)
    expect(payment).toBeDefined()
    expect(payment.provider).toBe(providerAddress)
    expect(payment.modelId).toBe(modelId)
    expect(payment.cohortId).toBe(1)
    expect(payment.amount).toBe(1000)
    
    // Check token balance
    const balance = mockTokenBalances.get(providerAddress)
    expect(balance).toBe(1000)
  })
  
  it("should not make payment for non-existent model", () => {
    const providerAddress = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
    
    const paymentResult = paymentCalculation.makePayment(
        providerAddress,
        999, // non-existent model ID
        1, // cohort ID
    )
    
    expect(paymentResult.type).toBe("err")
    expect(paymentResult.value).toBe(101) // ERR-MODEL-NOT-FOUND
  })
  
  it("should make multiple payments to the same provider", () => {
    // Create payment model
    const createResult = paymentCalculation.createPaymentModel(
        "Diabetes Care",
        "Payment model for diabetes management",
        1000, // base amount
        10, // outcome bonus percent
        5, // risk adjustment factor
    )
    const modelId = createResult.value
    
    const providerAddress = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
    
    // Make first payment
    paymentCalculation.makePayment(
        providerAddress,
        modelId,
        1, // cohort ID
    )
    
    // Make second payment
    paymentCalculation.makePayment(
        providerAddress,
        modelId,
        2, // different cohort ID
    )
    
    // Check token balance (should be 2000)
    const balance = mockTokenBalances.get(providerAddress)
    expect(balance).toBe(2000)
    
    // Check payment records
    expect(mockPayments.size).toBe(2)
  })
})
