# Test Case Documentation
## Test Case 001: Basic MTK Device Verification
- **Device**: MediaTek MT6580 Android Device
- **Test Date**: 2025-12-12
- **Purpose**: Validate MTK chipset detection algorithm

### Test Steps:
1. Connect device via USB with ADB debugging enabled
2. Run: .\src\phone_passport_run.ps1
3. Verify MTK chipset detection in output
4. Check hardware specifications accuracy

### Expected Results:
- MTK platform correctly identified
- CPU cores: 4 or 8 detected
- RAM capacity within expected range
- Storage partitions correctly enumerated

### Actual Results:
[To be filled after test execution]

## Test Case 002: Clone Detection Simulation
- **Device**: Modified Android device with mismatched specs
- **Test Date**: 2025-12-12
- **Purpose**: Test clone detection algorithm

### Test Steps:
1. Device with modified build.prop (fake specifications)
2. Run forensic analysis
3. Verify discrepancy detection

### Expected Results:
- High risk score (>70%)
- Multiple discrepancies flagged
- Clone warning issued

### Notes:
This test case demonstrates the core innovation of the method.
