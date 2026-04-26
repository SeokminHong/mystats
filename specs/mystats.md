# mystats 스펙

상태: Draft  
작성일: 2026-04-26  
대상: M1-M4 Apple Silicon Mac용 macOS 메뉴바 모니터링 앱

## 1. 제품 원칙

`mystats`는 M1-M4 계열 Apple Silicon Mac에서 CPU, GPU, 온도, 디스크 I/O, 네트워크 I/O를 메뉴바와 팝오버에서 빠르게 확인하는 경량 모니터링 앱이다.

목표는 iStat Menus처럼 가능한 모든 하드웨어 정보를 완전하게 보여주는 것이 아니라, 일반 사용자 권한으로 안정적으로 수집할 수 있는 핵심 지표를 낮은 오버헤드로 표시하는 것이다.

핵심 원칙:

- 읽을 수 있고 검증 가능한 값만 표시한다.
- 모니터링으로 인한 성능 저하는 최대한 줄인다.
- 성능 저하를 줄이기 위해 측정 정확도를 임의로 낮추지 않는다.
- 확실하지 않은 센서명은 단정하지 않는다.
- 권한 상승, root helper, 팬 제어, 전력 제어 기능은 넣지 않는다.
- GPU와 온도는 best effort 지표로 취급한다.
- 수집 실패는 앱 크래시가 아니라 지표 상태로 표현한다.
- 불확실한 값은 숨기거나 `Experimental`, `Unsupported`, `Unavailable`로 명시한다.
- 외부 런타임이나 별도 데몬 없이 단독 실행 가능한 앱을 기본 목표로 한다.

## 2. 지원 범위

지원 대상:

- CPU 아키텍처: Apple Silicon 전용
- 칩 범위: M1, M2, M3, M4 계열
- 앱 형태: macOS 메뉴바 앱
- 실행 권한: 일반 사용자 권한
- 제품명: mystats
- bundle identifier: `com.seokmin.mystats`
- 최소 macOS 버전: macOS 13.0
- 배포: 사용자 개인 Homebrew tap을 통한 배포
- 코드 서명 및 공증: 배포 버전에서 적용

지원하지 않는 대상:

- Intel Mac
- root 권한 helper
- 팬 제어
- 전력 제어
- 배터리 충전 제어
- 프로세스별 상세 분석
- GPU 코어별 또는 유닛별 사용률
- ANE 사용률
- 정확한 전력 측정
- 모든 센서명에 대한 정확도 보장
- 필수 외부 CLI, 필수 background daemon, 필수 별도 서버

## 3. MVP 기능 범위

반드시 지원하는 기능:

- 메뉴바 상시 표시
- CPU 전체 사용률
- CPU 코어별 사용률
- CPU P-core/E-core 평균, 구분 가능할 때만
- 네트워크 download/upload 속도
- 디스크 read/write 속도
- 최근 60초-5분 ring buffer 기반 그래프
- 설정 저장
- 로그인 시 자동 실행

조건부로 지원하는 기능:

- GPU 전체 사용률
- CPU/GPU/SoC 추정 온도
- 시스템 thermal state
- unknown sensor debug view

MVP에서 제외하는 기능:

- 팬 제어
- root helper
- 전력 제어
- GPU 유닛별 사용률
- ANE 사용률
- 센서명 정확도 보장
- 알림
- App Store 배포 최적화

## 4. 정확도와 오버헤드 정책

`mystats`는 측정 자체의 정확도를 제품 품질의 핵심으로 둔다. 경량화는 샘플링 스케줄, collector 실행 비용, UI 갱신 빈도, 메모리 보관 범위를 조절해서 달성한다.

정확도 원칙:

- 안정 지표인 CPU, network, disk는 OS가 제공하는 누적 counter 또는 tick delta를 기준으로 계산한다.
- 샘플 간 elapsed time은 실제 monotonic time을 사용한다.
- 표시 편의를 위해 원본 측정값을 과도하게 smoothing하지 않는다.
- 메뉴바 표시에는 반올림과 단위 축약을 적용할 수 있지만, 내부 snapshot과 ring buffer에는 계산 가능한 원본 정밀도를 보존한다.
- 값이 의심스러우면 추정 보정보다 `Experimental`, `Unavailable`, `Unsupported` 상태를 우선한다.

오버헤드 원칙:

- collector는 필요한 시점에만 실행하고, UI 렌더링이 collector를 직접 호출하지 않는다.
- 팝오버가 닫혀 있을 때는 샘플링 주기를 낮춘다.
- disk/network처럼 누적 counter 기반 지표는 비싼 재탐색을 매 샘플마다 반복하지 않는다.
- 센서 목록 탐색, capability detection, 외장 디스크 목록 갱신처럼 비용이 큰 작업은 캐시하고 필요할 때만 갱신한다.
- graph history는 메모리 ring buffer로 제한하며 영구 저장하지 않는다.

우선순위:

```text
1. 잘못된 값 표시 방지
2. 안정 지표의 측정 정확도
3. 낮은 idle CPU/메모리 사용량
4. 메뉴바 반응성
5. 조건부 지표 범위 확대
```

정확도와 오버헤드가 충돌할 때는 잘못된 값을 빠르게 표시하는 것보다, 더 낮은 빈도로 정확한 값을 표시하는 쪽을 선택한다.

## 5. 외부 의존성 정책

앱은 기본적으로 단독 실행 가능해야 한다.

허용되는 의존성:

- macOS system framework
- Swift standard library 및 Apple 제공 API
- 앱 번들 안에 포함되는 자체 코드
- 배포 산출물에 정적으로 포함되는 작은 native helper 또는 library

피해야 하는 의존성:

- Homebrew로 별도 설치해야 하는 runtime dependency
- 앱 실행에 필요한 외부 CLI
- 앱 실행에 필요한 별도 서버 또는 daemon
- 사용자가 직접 설치해야 하는 Rust, Python, Node.js runtime

GPU/온도 구현에서 `macmon`은 참고 구현 또는 알고리즘 검토 대상으로 우선 사용한다. `mystats`의 기본 배포물은 `macmon` CLI나 별도 서비스를 runtime dependency로 요구하지 않는다.

외부 코드를 포함해야 하는 경우:

- 라이선스가 배포 목적과 충돌하지 않아야 한다.
- 필요한 collector 범위만 작게 분리한다.
- 앱 번들 또는 빌드 산출물에 포함되어 단독 실행 가능해야 한다.
- 사용자가 별도 설치해야 하는 단계가 없어야 한다.
- 포함 이유와 대체 가능성을 스펙 또는 ADR에 기록한다.

## 6. 상태 모델

모든 지표는 값뿐 아니라 수집 상태를 함께 가진다.

```swift
enum MetricStatus {
    case available
    case experimental
    case unsupported
    case unavailable(reason: String)
}
```

상태 의미:

- `available`: 현재 기기에서 정상 수집 가능하며 값이 유효하다.
- `experimental`: 값은 수집되지만 기기별 검증이 충분하지 않다.
- `unsupported`: 현재 기기 또는 현재 빌드에서 지원하지 않는다.
- `unavailable`: 지원 가능성이 있으나 이번 샘플에서 수집에 실패했다.

표시 정책:

- `available`: 정상 값 표시
- `experimental`: 값 표시와 함께 실험적 상태를 UI에 드러냄
- `unsupported`: `Unsupported` 표시
- `unavailable`: `Unavailable` 표시, 상세 원인은 로그에 기록

collector 실패 처리:

```text
collector 실패
  -> 해당 지표를 unavailable 처리
  -> UI에서 Unsupported 또는 Unavailable 표시
  -> lightweight log에 원인 기록
  -> 다음 샘플에서 재시도
```

수집 실패는 앱 종료 조건이 아니다.

## 7. 앱 구조

초기 프로젝트는 외부 의존성을 줄이기 위해 SwiftPM 기반 SwiftUI macOS 앱으로 구성한다. Xcode project는 필수 산출물이 아니며, 빌드와 실행은 `swift build`와 프로젝트 로컬 실행 스크립트가 담당한다.

기본 구조:

```text
mystats.app
  App/
    MystatsApp
    MenuBarRootView

  UI/
    MenuBarLabelView
    PopoverView
    CPUSectionView
    GPUSectionView
    ThermalSectionView
    DiskSectionView
    NetworkSectionView
    SettingsView

  Metrics/
    MetricSnapshot
    MetricStore
    RingBuffer
    MetricStatus

  Collectors/
    MetricCollector
    CPUCollector
    GPUCollector
    ThermalCollector
    DiskCollector
    NetworkCollector
    CapabilityDetector

  Settings/
    AppSettings
    SettingsStore

  Utilities/
    ByteFormatter
    PercentageFormatter
    TemperatureFormatter
    Logger
```

UI는 SwiftUI `MenuBarExtra`를 기본 진입점으로 사용한다.

`MetricStore`는 최신 snapshot과 지표별 ring buffer를 보관한다. `SamplerScheduler`는 collector별 샘플링 주기를 관리하고, 팝오버 열림/닫힘 상태에 따라 샘플링 간격을 조정한다.

## 8. Collector 계약

collector는 각 지표의 수집 책임만 가진다. UI, 설정 저장, ring buffer 갱신을 직접 수행하지 않는다.

```swift
protocol MetricCollector {
    associatedtype Output

    var name: String { get }
    var isAvailable: Bool { get }

    func sample() throws -> Output
}
```

규칙:

- `sample()`은 가능한 한 짧게 실행되어야 한다.
- 수집 실패는 throw로 표현한다.
- 수집 값 검증은 collector 또는 collector와 가까운 validator에서 수행한다.
- 비정상값은 정상값으로 보정하지 않는다.
- collector 내부에 UI 표시 문구를 넣지 않는다.
- 기기별 특수 처리는 `CapabilityDetector` 또는 collector 내부의 명시적 capability 분기로 제한한다.
- collector는 외부 프로세스를 실행하지 않는 것을 기본으로 한다.

## 9. 데이터 모델

```swift
struct MetricSnapshot {
    let timestamp: Date
    let cpu: CPUMetrics?
    let gpu: GPUMetrics?
    let thermal: ThermalMetrics?
    let disk: DiskMetrics?
    let network: NetworkMetrics?
}
```

CPU:

```swift
struct CPUMetrics {
    let totalUsage: Double
    let perCoreUsage: [CoreUsage]
    let performanceCoreAverage: Double?
    let efficiencyCoreAverage: Double?
    let status: MetricStatus
}

struct CoreUsage {
    let id: Int
    let kind: CoreKind
    let usage: Double
}

enum CoreKind {
    case performance
    case efficiency
    case unknown
}
```

GPU:

```swift
struct GPUMetrics {
    let totalUsage: Double?
    let frequencyMHz: Double?
    let status: MetricStatus
}
```

Thermal:

```swift
struct ThermalMetrics {
    let cpuCelsius: Double?
    let gpuCelsius: Double?
    let socCelsius: Double?
    let thermalState: ThermalStateLabel
    let unknownSensors: [SensorReading]
    let status: MetricStatus
}
```

Disk:

```swift
struct DiskMetrics {
    let readBytesPerSecond: UInt64
    let writeBytesPerSecond: UInt64
    let status: MetricStatus
}
```

Network:

```swift
struct NetworkMetrics {
    let downloadBytesPerSecond: UInt64
    let uploadBytesPerSecond: UInt64
    let activeInterfaces: [NetworkInterfaceMetric]
    let status: MetricStatus
}
```

## 10. Capability Detection

M1-M4 지원은 모델명 하드코딩보다 기능 감지를 우선한다.

감지 항목:

- Apple Silicon 여부
- chip name, 확인 가능할 때
- logical CPU core count
- P-core/E-core 구분 가능 여부
- GPU collector 사용 가능 여부
- thermal sensor collector 사용 가능 여부
- known sensor mapping 사용 가능 여부
- disk statistics 접근 가능 여부
- network interface statistics 접근 가능 여부

```swift
struct DeviceCapabilities {
    let isAppleSilicon: Bool
    let chipName: String?
    let cpuCoreCount: Int
    let supportsCoreGrouping: Bool
    let supportsGPUUsage: Bool
    let supportsTemperatureSensors: Bool
    let supportsDiskIO: Bool
    let supportsNetworkIO: Bool
}
```

Apple Silicon이 아닌 기기에서는 앱 실행을 막거나 주요 지표를 `Unsupported`로 표시한다. MVP에서는 Apple Silicon 전용 앱으로 배포하는 것을 기본값으로 한다.

## 11. CPU 지표

지원 수준: 안정 지원

수집 방식:

- Mach `host_processor_info`로 logical CPU별 tick 값을 읽는다.
- 이전 샘플과 현재 샘플의 delta를 계산한다.
- 사용률은 `(user + system + nice) delta / total delta`로 계산한다.
- idle tick은 사용률 분자에서 제외한다.

표시 항목:

- CPU Total
- Per-core usage
- P-core average, 가능할 때
- E-core average, 가능할 때

P-core/E-core 그룹핑:

- capability detector가 구분할 수 있을 때만 표시한다.
- 구분 실패 시 코어별 목록을 `Core 0`, `Core 1`처럼 표시하고 그룹 평균은 숨긴다.
- 하드코딩된 세대별 코어 수에 의존하지 않는다.

완료 기준:

- idle 상태에서 낮은 사용률을 표시한다.
- single-core 부하에서 일부 코어 사용률이 증가한다.
- multi-core 부하에서 total usage가 증가한다.
- Activity Monitor 또는 `top`과 큰 흐름이 유사하다.

## 12. GPU 지표

지원 수준: 조건부 지원

MVP 결정:

- GPU는 전체 사용률만 표시한다.
- GPU 코어별 또는 유닛별 사용률은 지원하지 않는다.

구현 후보 우선순위:

1. `macmon` 방식 참고 후 앱 내부 collector로 필요한 범위만 재구현
2. IOReport/IOKit 기반 자체 collector
3. 수집 실패 시 `Unsupported` 표시

외부 의존성 정책:

- `macmon` CLI를 runtime dependency로 요구하지 않는다.
- Rust library를 쓰더라도 앱 번들에 포함되는 정적 library 또는 내부 native module 형태여야 한다.
- 별도 background service 방식은 MVP에서 제외한다.

표시 항목:

```text
GPU
Total        18%
Detail       Unsupported
```

값 검증:

- NaN은 표시하지 않는다.
- 음수는 표시하지 않는다.
- 100% 초과 값은 표시하지 않는다.
- idle과 부하 상태 모두에서 장시간 0%로 고정되면 `Unsupported` 또는 `Unavailable`로 전환하는 기준을 검토한다.

완료 기준:

- 지원 기기에서 GPU 부하 시 total usage가 증가한다.
- idle 상태에서 낮은 값으로 돌아온다.
- 지원하지 않는 기기나 실패한 collector는 앱을 죽이지 않고 `Unsupported` 또는 `Unavailable`로 표시한다.

## 13. 온도 지표

지원 수준: 조건부 지원

MVP 결정:

- 정확한 센서명을 단정하지 않는다.
- 센서 값은 느슨한 그룹으로만 표시한다.

표시 그룹:

- CPU
- GPU
- SoC
- Battery / NAND, 발견 시
- Unknown, 설정에서만 표시

구현 후보 우선순위:

1. `macmon` 방식 참고 후 앱 내부 Apple Silicon sensor collector 구현
2. known sensor key mapping
3. `ProcessInfo.thermalState` fallback

외부 의존성 정책:

- 온도 수집을 위해 별도 CLI나 daemon을 실행하지 않는다.
- 센서 키 mapping은 앱 내부 데이터로 관리한다.
- mapping 신뢰도가 낮으면 값을 표시하지 않고 thermal state fallback을 사용한다.

thermal state는 숫자 온도를 대체하는 안전한 fallback이다. 센서 온도를 읽지 못하면 섭씨 온도 대신 `Nominal`, `Fair`, `Serious`, `Critical` 같은 상태를 표시한다.

센서명 정책:

- 확실한 경우만 `CPU`, `GPU`, `SoC`로 묶는다.
- 불확실한 경우 `Sensor A`, `Sensor B`, `Unknown Sensor`처럼 표시한다.
- unknown sensor는 기본적으로 숨기고, 설정에서 `알 수 없는 센서 표시`를 켰을 때만 노출한다.

값 검증:

- NaN은 표시하지 않는다.
- 비현실적으로 낮거나 높은 값은 표시하지 않는다.
- sleep/wake 이후 값이 고정되면 collector reset을 수행한다.
- M4 계열처럼 센서 매핑 신뢰도가 낮은 기기는 검증된 값만 표시한다.

완료 기준:

- 지원 기기에서 CPU/GPU/SoC 추정 온도가 표시된다.
- 지원하지 않는 기기에서는 thermal state fallback 또는 `Unsupported`가 표시된다.
- 부하 증가 시 온도 흐름이 상승 방향으로 반응한다.
- 비정상 센서값은 숨긴다.

## 14. 디스크 I/O 지표

지원 수준: 안정 지원

수집 방식:

- IOKit block storage driver statistics에서 누적 read/write bytes를 읽는다.
- 샘플 간 delta와 elapsed time으로 초당 byte 속도를 계산한다.

계산:

```text
read bytes per second = (currentReadBytes - previousReadBytes) / deltaTime
write bytes per second = (currentWriteBytes - previousWriteBytes) / deltaTime
```

MVP 합산 정책:

- 내부 SSD 중심으로 표시한다.
- 외장 디스크는 설정에서 포함 여부를 선택할 수 있다.
- APFS 컨테이너별 세부 분리는 MVP에서 제외한다.

표시 항목:

- Disk Read
- Disk Write

완료 기준:

- 대용량 파일 복사 중 read/write 값이 증가한다.
- idle 상태에서 낮은 값으로 돌아온다.
- 외장 디스크 포함 설정이 표시 값에 반영된다.

## 15. 네트워크 I/O 지표

지원 수준: 안정 지원

수집 방식:

- `getifaddrs()`로 인터페이스 목록과 통계를 읽는다.
- byte counter의 샘플 간 delta와 elapsed time으로 download/upload 속도를 계산한다.

계산:

```text
download = rx bytes delta / deltaTime
upload = tx bytes delta / deltaTime
```

기본 포함:

- `en0`
- `en1`
- 활성 Wi-Fi
- 활성 Ethernet

기본 제외:

- `lo0`
- `awdl`
- `llw`
- `utun`
- `bridge`
- inactive interface

VPN 트래픽:

- `utun`은 기본 제외한다.
- 사용자가 VPN 트래픽 포함 설정을 켜면 포함한다.
- 중복 집계 가능성은 UI 또는 설정 설명에 드러낸다.

완료 기준:

- Wi-Fi 다운로드 중 download 값이 증가한다.
- 업로드 중 upload 값이 증가한다.
- VPN on/off 설정이 집계 대상에 반영된다.
- AirDrop/nearby 관련 인터페이스가 기본값에 섞이지 않는다.

## 16. 샘플링 정책

기본 샘플링은 앱 자체가 시스템 부하가 되지 않도록 보수적으로 잡는다.

팝오버 열림:

| 지표 | 주기 |
| --- | ---: |
| CPU | 1초 |
| Network | 1초 |
| Disk | 1초 |
| GPU | 2초 |
| Temperature | 3초 |
| Thermal State | 이벤트 기반 + 5초 fallback |

팝오버 닫힘:

| 지표 | 주기 |
| --- | ---: |
| CPU | 2초 |
| Network | 2초 |
| Disk | 2초 |
| GPU | 5초 |
| Temperature | 10초 |
| Thermal State | 이벤트 기반 + 10초 fallback |

설정의 샘플링 모드:

- 낮음: 기본 주기보다 느리게 샘플링한다.
- 보통: 위 기본값을 사용한다.
- 높음: 팝오버 열림 상태의 반응성을 우선하되 idle CPU 사용량을 검증해야 한다.

샘플링 정책 변경은 `SamplerScheduler`에 모아 둔다. 각 collector가 자체 timer를 가지지 않는다.

정확도 정책:

- 샘플링 주기를 낮추더라도 각 샘플의 계산은 실제 counter delta와 elapsed time으로 수행한다.
- 메뉴바가 닫힌 상태에서 낮은 빈도로 샘플링한 값을 높은 빈도처럼 보간하지 않는다.
- 누락된 샘플은 숨기거나 gap으로 처리하고 임의 값을 채우지 않는다.

성능 예산:

- idle 상태에서 앱의 CPU 사용량은 지속적으로 낮아야 한다.
- 팝오버 닫힘 상태에서는 UI 갱신과 collector 실행을 최소화한다.
- 장시간 실행 시 ring buffer 크기 이상으로 메모리가 증가하지 않아야 한다.

## 17. Ring Buffer 정책

그래프는 최근 샘플만 보관한다.

- 기본 표시 범위: 최근 60초
- 확장 가능 범위: 최대 5분
- 저장 위치: 메모리
- 앱 재시작 후 그래프 히스토리 복원은 MVP에서 제외

ring buffer는 값과 timestamp를 함께 저장한다. 샘플링 간격이 달라질 수 있으므로 배열 인덱스만으로 시간 간격을 추정하지 않는다.

## 18. 메뉴바 UI

기본 메뉴바 표시 항목:

```text
CPU | GPU | Temp | Network
```

각 지표는 하나의 긴 메뉴바 문자열로 합치지 않고, 독립된 `MenuBarExtra` 항목으로 표시한다. 사용자는 manager window에서 각 지표 항목을 켜고 끌 수 있다.

디스크는 기본 메뉴바 표시에서 제외한다. 디스크 read/write는 순간적인 변동이 커서 메뉴바가 지나치게 시끄러워질 수 있기 때문이다.

manager window를 열기 위한 작은 control 메뉴바 항목은 항상 표시한다. 모든 지표 항목을 끈 상태에서도 사용자가 다시 설정을 열 수 있어야 하기 때문이다.

기본 텍스트 예:

```text
CPU 32%
GPU 18%
61°C
↓12.4 ↑1.8
```

축약 텍스트 예:

```text
C32 G18 61°
```

표시 규칙:

- 메뉴바 항목은 지표별로 고정폭을 가진다.
- 고정폭은 표시값이 변해도 레이아웃 시프트가 발생하지 않도록 지표별 최대 예상 문자열 기준으로 정한다.
- 숫자는 monospaced digit을 사용한다.
- 메뉴바 텍스트는 짧게 유지한다.
- 각 항목은 해당 지표를 나타내는 system icon을 함께 표시한다.
- 메뉴바 항목에는 작은 sparkline chart를 표시할 수 있다. 차트 역시 고정폭 영역 안에 렌더링한다.
- 값이 `unsupported` 또는 `unavailable`인 항목은 메뉴바에서 숨길 수 있다.
- 사용자가 manager window에서 메뉴바 표시 항목을 선택할 수 있다.
- 네트워크와 디스크 단위는 읽기 쉬운 단위로 자동 축약한다.

## 19. 팝오버 UI

팝오버는 선택한 메뉴바 지표의 현재 snapshot과 최근 그래프를 우선 표시한다. 필요한 경우 다른 지표 요약으로 이동할 수 있지만, MVP에서는 클릭한 지표의 detail popover를 기본으로 한다.

기본 구성:

```text
CPU
Total        32%
P-cores      41%
E-cores      12%

Core Usage
P0  ███████░░░  71%
P1  ████░░░░░░  39%
E0  ██░░░░░░░░  18%

GPU
Total        18%
Detail       Unsupported

Temperature
CPU          61°C
GPU          54°C
SoC          63°C
Thermal      Nominal

Disk
Read         128 MB/s
Write         34 MB/s

Network
Download      12.4 MB/s
Upload         1.8 MB/s
```

팝오버 규칙:

- 불확실한 센서명은 정확한 코어명처럼 표시하지 않는다.
- `Unsupported`와 `Unavailable`을 구분한다.
- 설정으로 숨긴 항목은 섹션 전체를 숨긴다.
- 지표별 collector 상태를 사용자가 이해할 수 있는 수준으로 표시한다.
- 각 detail popover는 icon, 현재값, status badge, sparkline chart를 포함한다.
- manager window로 이동하는 버튼을 제공한다.

## 20. Manager Window

`mystats`는 메뉴바 항목을 켜고 끄는 manager window를 제공한다. manager window는 `WindowGroup(id: "manager")`로 구성하고, 각 메뉴바 popover에서 열 수 있어야 한다.

manager window 기능:

- CPU, GPU, Temperature, Network, Disk 메뉴바 항목 on/off
- 각 항목의 현재 상태와 최신값 표시
- 각 항목의 고정폭 메뉴바 preview 표시
- 샘플링 모드 설정
- unknown sensor, VPN interface, external disk, temperature unit 설정
- 시작 시 자동 실행 설정

manager window UI 정책:

- macOS 표준 utility/settings window처럼 동작한다.
- 항목별 toggle은 즉시 저장한다.
- 지표 상태는 icon, title, latest value, status, mini chart로 표시한다.
- 메뉴바에서 모든 지표를 끄는 것은 허용하되, 항상 표시되는 control 메뉴바 항목으로 manager window를 다시 열 수 있어야 한다.

## 21. 설정

설정 저장은 `UserDefaults`로 충분하다.

```swift
struct AppSettings: Codable {
    var menuBarItems: [MenuBarItem]
    var samplingMode: SamplingMode
    var showUnknownSensors: Bool
    var includeVPNInterfaces: Bool
    var includeExternalDisks: Bool
    var launchAtLogin: Bool
    var temperatureUnit: TemperatureUnit
}
```

필수 설정:

- 메뉴바에 표시할 항목
  - CPU
  - GPU
  - Temperature
  - Network
  - Disk
- 샘플링 간격
  - 낮음
  - 보통
  - 높음
- 시작 시 자동 실행
- 알 수 없는 센서 표시
- VPN 인터페이스 포함
- 외장 디스크 포함
- 온도 단위
  - Celsius
  - Fahrenheit

로그인 시 자동 실행:

- macOS 13 이상에서는 `SMAppService` 사용을 기본 후보로 둔다.
- 실패 시 설정 UI에서 명시적으로 실패를 표시한다.

## 22. 상태 색상

MVP 색상 정책은 단순하게 둔다.

CPU/GPU:

| 범위 | 상태 |
| --- | --- |
| 0-49% | normal |
| 50-79% | elevated |
| 80-100% | high |

Temperature:

| 범위 | 상태 |
| --- | --- |
| 0-69°C | normal |
| 70-84°C | warm |
| 85°C 이상 | hot |

Thermal State:

| 값 | 상태 |
| --- | --- |
| nominal | normal |
| fair | warm |
| serious | hot |
| critical | critical |

온도 기준은 기기마다 다르므로 위험 경고가 아니라 참고 표시로만 사용한다.

## 23. 개발 단계

### Phase 1: 기본 메뉴바 앱

목표:

- SwiftUI `MenuBarExtra` 앱 생성
- 지표별 독립 메뉴바 항목 표시
- 메뉴바 항목 고정폭 표시
- icon과 mini chart가 포함된 메뉴바 label
- 지표별 팝오버 UI
- manager window UI
- 설정 저장
- ring buffer 구조 구현
- 프로젝트 로컬 build/run 스크립트 구성
- Codex Run action 구성

완료 기준:

- 앱 실행 시 메뉴바에 표시된다.
- 설정에서 켠 지표가 각각 독립 메뉴바 항목으로 표시된다.
- 메뉴바 숫자 변화가 항목 폭을 바꾸지 않는다.
- 지표별 팝오버가 열린다.
- manager window에서 지표 on/off와 기본 설정을 변경할 수 있다.
- 설정 변경이 저장된다.
- 샘플 데이터로 그래프와 bar UI를 표시할 수 있다.
- `swift build`가 성공한다.
- `script/build_and_run.sh --verify`가 앱 프로세스 실행을 확인한다.

### Phase 2: 안정 지표 구현

대상:

- CPU total
- CPU per-core
- network download/upload
- disk read/write

완료 기준:

- CPU 전체 사용률이 Activity Monitor와 큰 흐름이 유사하다.
- 코어별 사용률이 부하 테스트에 반응한다.
- 네트워크 download/upload가 실제 전송 중 증가한다.
- 디스크 read/write가 파일 복사 중 증가한다.

### Phase 3: Apple Silicon 확장 지표 구현

대상:

- P-core/E-core 그룹핑
- GPU total usage
- CPU/GPU/SoC temperature
- thermal state fallback

완료 기준:

- 지원 기기에서 GPU 전체 사용률을 표시한다.
- 지원 기기에서 온도를 표시한다.
- 지원하지 않는 기기에서 `Unsupported`로 표시한다.
- 비정상 센서값을 숨긴다.
- collector 실패 시 앱이 크래시하지 않는다.

### Phase 4: M1-M4 호환성 정리

대상:

- M1
- M1 Pro/Max/Ultra
- M2
- M2 Pro/Max/Ultra
- M3
- M3 Pro/Max/Ultra
- M4
- M4 Pro/Max 계열

완료 기준:

- CPU/network/disk는 모든 테스트 기기에서 동작한다.
- GPU/온도는 가능한 기기에서만 표시한다.
- 실패 기기는 명확하게 `Unsupported` 처리한다.
- unknown sensor는 기본 숨김 상태를 유지한다.

### Phase 5: 배포 품질 정리

대상:

- 코드 서명
- notarization
- Homebrew tap 배포
- 배포 산출물 생성 자동화
- crash log 수집 구조
- lightweight logging
- 에너지 사용량 점검

완료 기준:

- 앱 재시작 후 설정이 유지된다.
- 로그인 시 자동 실행이 가능하다.
- collector 오류가 로그에 남는다.
- 장시간 실행 시 메모리 증가가 없다.
- idle 상태에서 앱 CPU 사용량이 낮다.
- 사용자 개인 Homebrew tap에서 설치 가능한 cask 또는 formula가 준비된다.
- 설치 후 별도 runtime dependency 없이 앱이 실행된다.

## 24. 배포 정책

최종 배포 채널은 사용자 개인 Homebrew tap이다.

배포 목표:

- `brew tap`과 `brew install --cask` 흐름으로 설치 가능해야 한다.
- 앱은 설치 후 별도 CLI, daemon, runtime 설치 없이 실행되어야 한다.
- release artifact는 코드 서명 및 공증된 앱 bundle을 기준으로 한다.
- Homebrew cask는 version, sha256, URL, app stanza를 명확히 가진다.

초기 배포 형태:

```text
homebrew tap
  -> cask mystats
  -> signed/notarized zip 또는 dmg
  -> mystats.app 설치
```

App Store 배포:

- MVP 목표가 아니다.
- private API 또는 비공개 sensor 접근을 사용하는 경우 App Store 배포 가능성은 낮게 본다.
- App Store 가능성을 위해 측정 정확도나 단독 실행 원칙을 희생하지 않는다.

업데이트:

- MVP에서는 Homebrew tap 업데이트를 기본 업데이트 경로로 둔다.
- Sparkle은 필수 범위에서 제외한다.
- Sparkle을 추가할 경우 Homebrew 업데이트 경로와 충돌하지 않도록 별도 스펙을 작성한다.

## 25. 테스트 계획

CPU:

- idle 상태
- single-core 부하
- multi-core 부하
- P-core/E-core 부하 차이 확인
- Activity Monitor, `top`, 개발 검증용 `powermetrics`와 흐름 비교

GPU:

- Metal benchmark 실행
- 영상 재생
- 로컬 LLM GPU 사용
- idle 상태
- GPU 부하 시 값 증가 확인
- idle 상태에서 낮은 값 유지 확인
- 값이 0%에 고정되면 `Unsupported` 전환 검토

온도:

- idle 상태
- CPU 부하
- GPU 부하
- sleep/wake 이후
- 외부 모니터 연결 상태
- 부하 증가 시 온도 상승 방향 확인
- 비정상적으로 고정된 값 숨김 확인

디스크:

- 대용량 파일 복사
- 압축 해제
- 외장 디스크 연결
- Time Machine 동작 중

네트워크:

- Wi-Fi 다운로드
- 업로드
- Ethernet
- VPN on/off
- AirDrop 근처 상태

장시간 실행:

- idle 1시간 이상 실행
- 팝오버 반복 open/close
- sleep/wake 반복
- 메모리 증가 여부 확인
- 앱 자체 CPU 사용량 확인

UI:

- 각 지표가 독립 메뉴바 항목으로 표시되는지 확인
- manager window에서 항목 on/off가 즉시 반영되는지 확인
- 메뉴바 값 변화 중 항목 폭이 변하지 않는지 확인
- popover와 manager window의 mini chart가 ring buffer와 함께 갱신되는지 확인

배포:

- Homebrew tap에서 cask 설치
- 설치된 `mystats.app` 단독 실행
- 코드 서명 확인
- notarization 확인
- fresh machine에서 외부 runtime 없이 실행 확인

## 26. 리스크와 대응

| 리스크 | 영향 | 대응 |
| --- | ---: | --- |
| Apple Silicon 센서 키 변경 | 온도 오표시 | known mapping, unknown sensor, thermal fallback |
| GPU 사용률 수집 실패 | GPU 표시 불가 | `Unsupported` 표시 |
| M4 일부 모델에서 값 이상 | 신뢰도 하락 | 검증된 값만 표시 |
| collector 샘플링 비용 증가 | 앱 자체가 무거워짐 | 샘플링 간격 조절 |
| sleep/wake 후 값 고정 | 잘못된 표시 | wake 감지 후 collector reset |
| VPN 인터페이스 중복 집계 | 네트워크 값 과대 | 인터페이스 필터 설정 |
| 외장 디스크 포함 문제 | 디스크 값 혼란 | 내부 디스크 기본, 외장은 옵션 |
| 외부 collector 의존 | 설치/업데이트 복잡도 증가 | 앱 내부 collector 우선, 외부 CLI runtime dependency 금지 |
| 메뉴바 레이아웃 시프트 | 메뉴바 사용성 저하 | 지표별 fixed-width label과 monospaced digits |
| Homebrew tap 배포 산출물 불일치 | 설치 실패 | release artifact, sha256, cask 검증 자동화 |
| App Store 심사 리스크 | 배포 제한 | Homebrew tap 배포 우선 |

## 27. 미정 항목

구현 전 결정이 필요한 항목:

- GPU/온도 collector를 Swift/IOKit 계층만으로 구현할지, 정적으로 포함되는 native module을 둘지
- GPU/온도 collector에서 private API 사용을 허용할지
- unknown sensor debug view를 일반 설정에 둘지 개발자 설정으로 숨길지
- Homebrew tap repository 이름과 release artifact URL 규칙

현재 스펙의 기본 가정:

- GPU/온도는 MVP 핵심 안정 지표가 아니므로, 불확실하면 표시하지 않는 쪽을 선택한다.
- private API 사용 여부는 배포 정책과 함께 별도 결정한다.
- `macmon`은 runtime dependency가 아니라 참고 구현 또는 선택적 내부 구현 재료로만 취급한다.
- 최종 배포는 개인 Homebrew tap의 cask를 기준으로 한다.

## 28. 참고 자료

검토일: 2026-04-26

- Apple Developer: `MenuBarExtra`
  - https://developer.apple.com/documentation/SwiftUI/MenuBarExtra
- Apple Developer: `host_processor_info`
  - https://developer.apple.com/documentation/kernel/1502854-host_processor_info
- Apple Developer: `ProcessInfo.ThermalState`
  - https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum
- Apple Developer: `kIOBlockStorageDriverStatisticsBytesReadKey`
  - https://developer.apple.com/documentation/iokit/kioblockstoragedriverstatisticsbytesreadkey
- Apple Developer: `getifaddrs(3)`
  - https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getifaddrs.3.html
- Apple Developer: `SMAppService`
  - https://developer.apple.com/documentation/servicemanagement/smappservice
- `macmon`: Apple Silicon용 sudo 없는 실시간 모니터링 CLI 및 Rust library
  - https://github.com/vladkens/macmon
- Stats issue: M3 계열 센서 키 차이 사례
  - https://github.com/exelban/stats/issues/1703
- Stats issue: M4 Max 센서 목록 오류 사례
  - https://github.com/exelban/stats/issues/2233
