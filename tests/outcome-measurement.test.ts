import { describe, it, expect, beforeEach } from "vitest"

// Mock implementation for testing Clarity contracts

// Mock state
const mockOutcomeMetrics = new Map()
const mockPatientOutcomes = new Map()
let mockAdmin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM" // Example principal
let mockTxSender = mockAdmin
let mockNextMetricId = 1

// Helper function to create a patient outcome key
const createOutcomeKey = (metricId, cohortId, patientId) => `${metricId}-${cohortId}-${patientId}`

// Mock contract functions
const outcomeMeasurement = {
  createMetric: (name, description) => {
    if (mockTxSender !== mockAdmin) {
      return { type: "err", value: 100 } // ERR-NOT-AUTHORIZED
    }
    
    const metricId = mockNextMetricId
    
    mockOutcomeMetrics.set(metricId, {
      name,
      description,
      createdAt: 123, // Mock block height
      active: true,
    })
    
    mockNextMetricId++
    return { type: "ok", value: metricId }
  },
  
  recordOutcome: (metricId, cohortId, patientId, value) => {
    if (!mockOutcomeMetrics.has(metricId)) {
      return { type: "err", value: 101 } // ERR-METRIC-NOT-FOUND
    }
    
    const key = createOutcomeKey(metricId, cohortId, patientId)
    
    mockPatientOutcomes.set(key, {
      value,
      recordedAt: 123, // Mock block height
      provider: mockTxSender,
    })
    
    return { type: "ok", value: true }
  },
  
  getMetricDetails: (metricId) => {
    return mockOutcomeMetrics.get(metricId) || null
  },
  
  getPatientOutcome: (metricId, cohortId, patientId) => {
    const key = createOutcomeKey(metricId, cohortId, patientId)
    return mockPatientOutcomes.get(key) || null
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
describe("Outcome Measurement Contract", () => {
  beforeEach(() => {
    // Reset state before each test
    mockOutcomeMetrics.clear()
    mockPatientOutcomes.clear()
    mockAdmin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
    mockTxSender = mockAdmin
    mockNextMetricId = 1
  })
  
  it("should create a new outcome metric", () => {
    const result = outcomeMeasurement.createMetric("HbA1c", "Hemoglobin A1c blood test for diabetes monitoring")
    
    expect(result.type).toBe("ok")
    expect(result.value).toBe(1)
    
    const metric = mockOutcomeMetrics.get(1)
    expect(metric).toBeDefined()
    expect(metric.name).toBe("HbA1c")
    expect(metric.description).toBe("Hemoglobin A1c blood test for diabetes monitoring")
    expect(metric.active).toBe(true)
  })
  
  it("should not allow non-admin to create metrics", () => {
    mockTxSender = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG" // Different sender
    
    const result = outcomeMeasurement.createMetric("HbA1c", "Hemoglobin A1c blood test for diabetes monitoring")
    
    expect(result.type).toBe("err")
    expect(result.value).toBe(100) // ERR-NOT-AUTHORIZED
  })
  
  it("should record a patient outcome", () => {
    // Create metric first
    const createResult = outcomeMeasurement.createMetric("HbA1c", "Hemoglobin A1c blood test for diabetes monitoring")
    const metricId = createResult.value
    
    // Record outcome
    const recordResult = outcomeMeasurement.recordOutcome(
        metricId,
        1, // cohort ID
        "PATIENT123",
        65, // value (6.5%)
    )
    
    expect(recordResult.type).toBe("ok")
    expect(recordResult.value).toBe(true)
    
    // Check recorded outcome
    const outcome = outcomeMeasurement.getPatientOutcome(metricId, 1, "PATIENT123")
    expect(outcome).toBeDefined()
    expect(outcome.value).toBe(65)
    expect(outcome.provider).toBe(mockTxSender)
  })
  
  it("should not record outcome for non-existent metric", () => {
    const recordResult = outcomeMeasurement.recordOutcome(
        999, // non-existent metric ID
        1, // cohort ID
        "PATIENT123",
        65, // value
    )
    
    expect(recordResult.type).toBe("err")
    expect(recordResult.value).toBe(101) // ERR-METRIC-NOT-FOUND
  })
  
  it("should allow updating a patient outcome", () => {
    // Create metric first
    const createResult = outcomeMeasurement.createMetric("HbA1c", "Hemoglobin A1c blood test for diabetes monitoring")
    const metricId = createResult.value
    
    // Record initial outcome
    outcomeMeasurement.recordOutcome(
        metricId,
        1, // cohort ID
        "PATIENT123",
        65, // value (6.5%)
    )
    
    // Update outcome
    const updateResult = outcomeMeasurement.recordOutcome(
        metricId,
        1, // cohort ID
        "PATIENT123",
        60, // new value (6.0%)
    )
    
    expect(updateResult.type).toBe("ok")
    expect(updateResult.value).toBe(true)
    
    // Check updated outcome
    const outcome = outcomeMeasurement.getPatientOutcome(metricId, 1, "PATIENT123")
    expect(outcome).toBeDefined()
    expect(outcome.value).toBe(60)
  })
  
  it("should allow different providers to record outcomes", () => {
    // Create metric as admin
    const createResult = outcomeMeasurement.createMetric("HbA1c", "Hemoglobin A1c blood test for diabetes monitoring")
    const metricId = createResult.value
    
    // Change sender to provider
    mockTxSender = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
    
    // Record outcome as provider
    const recordResult = outcomeMeasurement.recordOutcome(
        metricId,
        1, // cohort ID
        "PATIENT123",
        65, // value
    )
    
    expect(recordResult.type).toBe("ok")
    expect(recordResult.value).toBe(true)
    
    // Check recorded outcome has correct provider
    const outcome = outcomeMeasurement.getPatientOutcome(metricId, 1, "PATIENT123")
    expect(outcome).toBeDefined()
    expect(outcome.provider).toBe("ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG")
  })
})
