# AutoBoat Wiki — Autonomous Navigation for Unmanned Surface Vehicles

![AutoBoat Banner](../images/logo_autoboat_v2.svg)
[![ROS 2](https://img.shields.io/badge/ROS_2-Jazzy-blue)](https://docs.ros.org/en/jazzy/)
[![Gazebo](https://img.shields.io/badge/Gazebo-Harmonic-orange)](https://gazebosim.org/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
![Status](https://img.shields.io/badge/Status-Active-green)

Welcome to the **AutoBoat Wiki**! This documentation provides comprehensive guides for using and developing the autonomous navigation system, built on the Virtual RobotX (VRX) simulation platform.

---

## 📚 Quick Navigation

### 🚀 Getting Started

- **[Installation Guide](Installation_Guide)** — Set up ROS 2, Gazebo, and AutoBoat
- **[Quick Start](Quick_Start)** — Get your first mission running in 5 minutes
- **[User Manual](https://github.com/Ghostzero00018/uvautoboat/blob/main/USER_MANUAL.md)** — Full operator reference (topics, services, parameters, troubleshooting)

### 🏗️ Architecture

- **[System Overview](System_Overview)** — High-level architecture and design philosophy
- **[Design Rationale](Design_Rationale)** — Why these architecture, algorithm, and parameter choices were made
- **[Glossary](Glossary)** — Plain-language definitions of every technical term
- **[Node Naming Refactor Plan](Node_Naming_Refactor_Plan)** — Completed rename: OKO/SPUTNIK/BURAN → functional names (lidar_perception, waypoint_planner, heading_controller)

### 🗺️ Roadmap

- **[Project Roadmap](Roadmap)** — Phase 5 hardware-deployment summary + research extensions (water quality, cellular automata, digital twin); Phase A (mock water quality sensor) consulting scope; open questions for supervisor

> **Note:** The former Vostok1 integrated and Atlantis architectures have been deprecated and moved to `legacy/`.

### 🔧 Module Deep Dives

- **[3D LIDAR Processing](3D_LIDAR_Processing)** — LiDAR Perception internals: temporal filtering, clustering, sector analysis
- **[Simple Anti-Stuck System (SASS)](SASS)** — Heading Controller escape behaviour: turn toward clearer side until front is clear

### 🐛 Troubleshooting & Security

- **[Common Issues](Common_Issues)** — Solutions to frequent problems
- **[Dashboard Security](Dashboard_Security)** — Security assessment, known vulnerabilities, and mitigation recommendations

---

## 🎯 Project Status

| Phase | Description | Status |
|:------|:------------|:------:|
| Phase 1 | Architecture & MVP | ✅ DONE |
| Phase 2 | Autonomous Navigation | ✅ DONE |
| Phase 3 | Coverage Planning | ⏸️ Planned |
| Phase 4 | Integration & Testing | 🔄 90% |
| Phase 5 | Real-Hardware Deployment | 🔜 Planned |

See [Board.md](https://github.com/Ghostzero00018/uvautoboat/blob/main/Board.md) for detailed milestones.

---

## 🤝 About

**Maintained By**: AutoBoat Development Team
**Institution**: [IMT Nord Europe](https://imt-nord-europe.fr/) — Industry 4.0 Students & Faculty
**License**: Apache 2.0

**Last Updated**: 21-04-2026

---

## 🔗 External Links

- **[GitHub Repository](https://github.com/Ghostzero00018/uvautoboat)**
- **[Report Issues](https://github.com/Ghostzero00018/uvautoboat/issues)**
- **[VRX Official Wiki](https://github.com/osrf/vrx/wiki)**
- **[ROS 2 Documentation](https://docs.ros.org/en/jazzy/)**
