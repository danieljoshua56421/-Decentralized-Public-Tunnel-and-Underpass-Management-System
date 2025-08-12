# Decentralized Public Tunnel and Underpass Management System

A comprehensive blockchain-based system for managing tunnel ventilation, drainage, lighting, cleaning, and emergency evacuation systems using Clarity smart contracts.

## System Overview

This system consists of five interconnected smart contracts that manage critical infrastructure for public tunnels and underpasses:

1. **Tunnel Ventilation System** - Air circulation and quality management
2. **Underpass Drainage Management** - Water level monitoring and flood prevention
3. **Tunnel Lighting Coordination** - Lighting control and maintenance
4. **Tunnel Cleaning Scheduling** - Maintenance scheduling and crew coordination
5. **Emergency Evacuation System** - Emergency protocols and communication

## Architecture

Each contract operates independently while maintaining data consistency and operational coordination. The system supports multiple tunnels, automated monitoring, scheduled maintenance, and emergency response protocols.

## Key Features

- Real-time system monitoring and status tracking
- Automated maintenance scheduling and crew assignment
- Emergency response protocols with automated alerts
- Energy-efficient operations with usage-based controls
- Comprehensive audit trails and compliance reporting
- Role-based access control for operators and administrators

## Contract Specifications

### Data Types
- Tunnel ID: uint (unique identifier)
- Equipment ID: uint (unique identifier)
- Status codes: uint (operational states)
- Timestamps: uint (block height based)
- Measurements: uint (sensor readings)

### Access Control
- Contract owner: Full administrative access
- Authorized operators: System operation and maintenance
- Emergency responders: Emergency protocol access
- Public: Read-only access to basic status information

## Installation and Setup

1. Install Clarinet CLI
2. Clone this repository
3. Run `clarinet check` to validate contracts
4. Execute `npm test` to run the test suite
5. Deploy contracts using `clarinet deploy`

## Usage Examples

### System Initialization
Initialize a new tunnel with all required systems and set operational parameters.

### Monitoring Operations
Regular monitoring of air quality, water levels, lighting status, and cleaning schedules.

### Emergency Response
Automated emergency protocols including ventilation activation, drainage pumps, and evacuation procedures.

## Testing

The system includes comprehensive test coverage using Vitest with scenarios for:
- Normal operations
- Emergency situations
- Maintenance procedures
- Error conditions
- Access control validation

## Contributing

Please follow the coding standards and ensure all tests pass before submitting pull requests. \`\`\`
