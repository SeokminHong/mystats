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
- 최근 15분 ring buffer 기반 그래프
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
- UI 렌더링용 graph history는 메모리 ring buffer와 minute rollup으로 제한한다.
- 원본 metric snapshot은 앱/기기 재시작 후에도 확인할 수 있도록 제한된 파일 로그로 남긴다.
- 파일 로그는 append-only JSON Lines 형식으로 작성하고, retention cleanup으로 저장량을 제한한다.

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
- Network 지표는 preview 값으로 대체하지 않는다. CPU/GPU/Disk 등 다른 collector가 아직 preview 단계여도 Network는 실제 counter delta를 우선 사용한다.
- 첫 샘플처럼 이전 counter가 없어 delta를 계산할 수 없는 경우에만 0으로 시작하고, 이후 샘플부터 실제 rate를 표시한다.
- preview snapshot은 Network history와 persistent log에 쓰지 않는다. 기존 preview log는 live source 표식이 없으면 Network history 복원에서 제외한다.

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
- metric log의 최근 window에서 network 값의 min/max/unique count를 확인해 값이 고정되어 있지 않은지 검증한다.
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

## 17. History와 Metric Log 정책

그래프는 최근 샘플만 보관한다.

- 기본 표시 범위: 실시간, 최근 15분
- 확장 표시 범위: 1일, 1주
- UI history 저장 위치: 메모리
- persistent metric log 저장 위치: `Application Support/mystats/MetricLogs`
- persistent metric log 형식: 하루 단위 `.jsonl`
- persistent metric log TTL: 7일
- persistent metric log cleanup 주기: 앱 시작 시 + 6시간마다
- 앱 재시작 후 최근 persistent metric log를 읽어 realtime ring buffer와 minute rollup을 복원한다.

ring buffer는 값과 timestamp를 함께 저장한다. 샘플링 간격이 달라질 수 있으므로 배열 인덱스만으로 시간 간격을 추정하지 않는다.

장기 window는 1초 raw sample을 모두 보관하지 않는다. 실시간 window는 짧은 raw ring buffer를 사용하고, 1일/1주 window는 분 단위 rollup snapshot을 사용한다. 이렇게 해야 1주 그래프를 제공하면서도 메뉴바 앱 자체의 메모리/CPU 비용을 통제할 수 있다.

persistent metric log policy:

- 샘플 collector가 생성한 snapshot만 파일에 기록한다. UI preview seed처럼 측정이 아닌 보정 데이터는 파일에 쓰지 않는다.
- 로그 파일에는 비밀값, 사용자 파일 경로, 프로세스별 정보, 네트워크 목적지 같은 민감한 상세 정보를 저장하지 않는다.
- network에는 byte rate와 interface 이름만 저장한다.
- collector가 값을 제공하지 못한 지표는 `null`로 남겨 missing value와 `0`을 구분한다.
- cleanup 실패는 앱 동작을 막지 않고 unified log에 원인을 남긴다.

chart time window:

- `Realtime`: 최근 15분 raw sample. 메뉴바 sparkline과 같은 raw ring buffer 범위를 사용한다.
- `1 Day`: 최근 24시간 minute rollup
- `1 Week`: 최근 7일 minute rollup
- popover chart는 긴 time window의 모든 point를 그대로 그리지 않는다. 통계와 current 값은 전체 window 데이터를 사용하되, 렌더링은 window별 표시 한도에 맞춰 downsample한다.
- 기본 렌더링 한도는 `Realtime` 약 300 points, `1 Day` 약 240 points, `1 Week` 약 336 points로 둔다.
- downsample은 첫 point와 최신 point를 보존하고, missing value를 `0`으로 채우지 않는다.

chart scale:

- CPU/GPU 사용률은 항상 0-100% 고정 축으로 표시한다.
- 온도는 기본 0-110°C 고정 축으로 표시하되, Fahrenheit 표시 시 같은 물리 범위를 변환해서 표시한다.
- network/disk byte rate는 현재 window의 min/max에 padding을 둔 adaptive 축을 사용한다.
- network/disk처럼 방향이 둘인 byte-rate chart는 download/upload 또는 read/write의 magnitude 차이가 커도 두 선이 모두 보여야 한다. summary와 detail 값은 실제 단위를 유지하되, chart 선은 각 방향의 trend를 독립 축으로 정규화할 수 있다.
- 팝오버의 방향성 byte-rate chart도 두 선이 겹쳐 한 줄처럼 보이면 안 된다. Network/Disk는 같은 chart 영역 안에서 방향별 vertical lane을 나누어 두 trend를 모두 읽을 수 있게 한다.
- chart y값은 current/detail/log에 쓰는 raw metric 값과 같은 `bytesPerSecond` 값을 사용한다. `4.3 MB/s` 같은 표시 문자열을 다시 파싱해 y값으로 쓰지 않는다.
- chart legend의 current 값은 history 배열의 마지막 값이 아니라 현재 snapshot을 기준으로 표시한다. history가 stale이거나 최신 snapshot을 아직 포함하지 않아도 메뉴바 current, detail current, legend current가 서로 달라져서는 안 된다.
- chart summary의 Current 값도 현재 snapshot을 기준으로 표시한다. history 마지막 값이 오래되었거나 같은 timestamp의 stale 값이면 최신 snapshot으로 교체해 chart와 summary가 `Zero KB/s` 같은 오래된 값을 표시하지 않게 한다.
- chart series는 현재 snapshot을 반드시 포함해야 한다. selected time window history가 최신 snapshot을 포함하지 못한 경우 chart resolver가 현재 snapshot을 마지막 point로 추가한다.
- byte-rate chart의 오른쪽 y축 label은 `High`/`Low` 같은 추상 텍스트가 아니라 현재 window의 raw `bytesPerSecond` 범위를 읽기 쉬운 `KB/s`, `MB/s`, `GB/s` 단위 숫자로 표시한다.
- 방향별 lane이 서로 다른 trend scale을 쓰더라도 오른쪽 y축 label은 chart window 전체 byte-rate 범위의 하한/상한을 나타낸다. 정확한 현재값, min/max/avg는 legend와 summary stat에서도 제공한다.
- 독립 trend 축도 순간 spike 하나 때문에 정상 구간이 일직선처럼 눌리면 안 된다. domain은 robust percentile 기반으로 잡고, 실제 min/max/current는 summary와 detail 값으로 보존한다.
- trend 축의 목적은 절대 byte-rate 비교가 아니라 변화량을 읽는 것이다. 따라서 중앙 percentile 범위를 우선 사용하고, 최소 표시 span은 절대값 magnitude보다 실제 변화가 보이는 쪽을 우선한다.
- trend 축은 latest/current sample을 반드시 domain 안에 포함하고 padding을 둔다. 최신 값이 percentile 밖에 있다는 이유로 chart 상단/하단에 붙어 일직선처럼 보여서는 안 된다.
- Network/Disk trend chart는 raw `bytesPerSecond`를 저장하고 summary/detail에 그대로 표시하되, y좌표 렌더링에는 `log1p` 같은 단조 압축 변환을 적용할 수 있다. 이는 spike와 평상시 값이 함께 있을 때 선이 일직선처럼 눌리는 것을 막기 위한 표시 정책이다.
- Network/Disk popover trend chart는 값 변화가 fill band에 묻혀 일직선처럼 보이면 안 된다. 기본 렌더링은 선을 우선하고, fill은 선의 변화량을 가리지 않는 경우에만 사용한다.
- adaptive 축은 값의 변화가 작아도 일직선처럼 눌리지 않도록 최소 표시 범위를 보장한다.
- adaptive 축은 순간 spike 하나가 전체 그래프를 평평하게 만들지 않도록 outlier에 덜 민감한 robust domain을 사용한다. 실제 min/max는 summary stat에 표시한다.
- 값이 실제로 0 근처에 걸쳐 있는 경우에는 0을 하한으로 포함하지만, 모든 값이 0에서 멀리 떨어져 있으면 무조건 0에 고정하지 않는다.
- 메뉴바 sparkline은 숫자 축 label이 없는 trend preview이므로, 다중선 지표의 각 선을 독립적으로 정규화해 낮은 magnitude의 upload/write 선도 변화가 보이게 한다.
- 메뉴바 다중선 sparkline은 동일한 작은 plot rect 안에서 선이 겹쳐 한 줄처럼 보이면 안 된다. Network/Disk는 각 방향을 분리된 vertical lane 또는 동등한 분리 표현으로 렌더링한다.
- 메뉴바 sparkline은 realtime raw sample 전체를 그대로 1px 이하 간격에 밀어 넣지 않고, 작은 폭에서 선 모양이 뭉개지지 않도록 표시 가능한 point 수로 downsample한다.
- preview/sample 데이터는 사인파 같은 주기 함수를 쓰지 않는다. 실제 collector가 들어오기 전에는 random walk와 occasional spike 형태의 deterministic preview를 사용한다.
- preview mode는 앱 시작 직후 chart가 일직선처럼 보이지 않도록 realtime raw sample을 deterministic preview data로 seed한다.
- 실제 collector mode에서는 측정되지 않은 시간을 preview 값이나 0으로 채우지 않는다.

chart gap policy:

- chart series는 값 배열만이 아니라 timestamp와 optional value를 함께 가진 point 목록으로 표현한다.
- 특정 timestamp에 값이 없으면 `0`으로 대체하지 않는다. 통계, 현재값, 축 계산에서도 missing value는 제외한다.
- chart x축 domain은 값이 있는 point의 첫/마지막 시간이 아니라 사용자가 선택한 time window 전체로 고정한다.
- 선택한 time window 안에서 측정값이 없는 앞/뒤 시간대는 축을 잘라내지 않고 빈 공간으로 남긴다.
- sleep/wake, collector pause, 장기 window rollup 누락 등으로 정상 샘플 간격보다 큰 시간 간격이 생기면 그 구간을 연속 실선으로 연결하지 않는다.
- 끊긴 구간은 gap으로 표현하며, 앞뒤 값이 모두 있는 경우에는 낮은 대비의 점선 connector로 표시할 수 있다.
- chart의 x 위치는 배열 index가 아니라 timestamp range 기준으로 계산한다.

## 18. 메뉴바 UI

기본 메뉴바 표시 항목:

```text
CPU | GPU | Temp | Network
```

각 지표는 하나의 긴 메뉴바 문자열로 합치지 않고, 독립된 `NSStatusItem` 항목으로 표시한다. 사용자는 settings window의 metric tab에서 각 지표 항목을 켜고 끌 수 있다.

디스크는 기본 메뉴바 표시에서 제외한다. 디스크 read/write는 순간적인 변동이 커서 메뉴바가 지나치게 시끄러워질 수 있기 때문이다.

별도의 master/control 메뉴바 아이콘은 두지 않는다. 설정과 종료는 모든 metric popover 상단에서 접근 가능해야 한다.

공통 메뉴바 항목 인터랙션:

- 각 metric item 클릭 시 해당 metric popover를 연다.
- 다른 metric item을 클릭하면 기존 popover를 닫고 새 popover만 연다.
- 같은 metric item을 다시 클릭하면 popover를 닫는다.
- metric popover가 열리면 앱을 활성화하고 popover window를 key window로 만들어 키보드 포커스가 popover 안으로 들어가야 한다.
- popover 외부를 클릭하거나 앱이 비활성화되면 popover는 닫혀야 한다.
- 각 popover의 `Settings`는 설정 가능한 manager/settings window를 열고 앞으로 가져온다.
- 각 popover의 `Quit mystats`는 앱을 종료한다.
- 모든 metric item을 끄면 설정 접근 경로가 사라지므로, 마지막으로 켜진 metric item은 끌 수 없게 한다.
- 앱 번들은 menu-bar-only accessory 앱으로 동작하며 Dock에는 표시하지 않는다.
- 앱 아이콘은 단순한 rounded square + metric line 형태로 제공하고, 앱 번들 `CFBundleIconFile`에 포함한다.
- 설정 창은 regular macOS window로 동작하며, 닫은 뒤에도 metric popover에서 다시 열 수 있어야 한다.

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
- 고정폭은 AppKit `NSStatusItem.length`로 강제하며, 표시값이 변해도 레이아웃 시프트가 발생하지 않도록 지표별 최대 예상 문자열 기준으로 정한다.
- 고정폭은 값이 잘리지 않는 범위 안에서 compact하게 유지한다. 기준 폭은 chart on 상태에서 CPU 112pt, GPU 106pt, Temperature 106pt, Network 102pt, Disk 128pt로 둔다.
- 메뉴바 chart를 끈 항목은 chart 영역만큼 `NSStatusItem.length`를 줄인다. chart off 상태에서도 해당 상태 안에서는 고정폭을 유지한다.
- status item 내부 렌더링은 불필요한 좌우 padding을 두지 않고, icon/text/sparkline을 1-2px 단위 여백으로 조밀하게 배치한다.
- chart가 켜진 상태에서 값과 chart 사이에는 4pt 안팎의 일정한 여백을 둔다.
- 숫자는 monospaced digit을 사용한다.
- 메뉴바 텍스트는 현재 상태 요약을 담되 1-2줄 안에 들어오게 압축한다.
- 메뉴바 표시 모델은 모든 지표에 `primary/secondary`를 강제하지 않는다.
- CPU처럼 주값과 하위 요약값이 있는 지표는 `primary + optional secondary` 레이아웃을 사용한다.
- Temperature처럼 secondary 값이 없는 지표는 메뉴바, popover current value, manager preview에서 secondary 영역 자체를 만들지 않는다.
- secondary 값이 없거나 설정에서 secondary 표시를 끈 경우 메뉴바 두 번째 줄에 `Live`, `Experimental`, `Unsupported`, `Unavailable` 같은 상태 텍스트를 대신 표시하지 않고, 단일 행 레이아웃으로 수직 중앙 정렬한다.
- metric status는 popover header, detail section, manager window에서만 표시한다.
- Network download/upload, Disk read/write처럼 동등한 위계의 값은 peer pair 레이아웃으로 표시하며, 두 값을 같은 크기와 위계로 렌더링한다.
- Network 메뉴바 항목도 다른 지표와 동일하게 leading system icon을 표시한다.
- chart가 켜진 단일값 메뉴바 항목은 텍스트를 chart 방향으로 정렬해 값 끝과 chart 시작 사이의 여백이 항목별로 비슷하게 보이도록 한다.
- CPU/GPU/Temperature처럼 leading icon이 있는 항목은 icon과 label/value 그룹 사이의 여백이 커지지 않도록 label/value 그룹의 오른쪽 정렬 이동량을 제한한다.
- Network/Disk peer pair 항목은 chart가 켜져 있어도 방향 label과 값을 chart 쪽으로 밀지 않고 start 방향에 둔다. icon, 방향 label, 값은 왼쪽에서 조밀하게 읽혀야 한다.
- Network/Disk peer pair 항목은 방향 label과 값을 하나의 compact group으로 붙여 표시한다. label과 값 사이의 여백은 3pt 안팎으로 유지하고, 값 영역은 현재 단위에서 유효숫자 3자리까지 표시할 수 있는 폭을 확보한다.
- leading icon이 있는 peer pair 항목은 icon과 방향 label 사이의 거리를 1-2pt 수준으로 조밀하게 유지한다.
- 메뉴바 sparkline chart 폭은 모든 지표에서 Disk 기준인 42pt로 통일한다.
- Network 메뉴바 항목은 leading icon과 download/upload 두 줄 값을 유지하되, icon-label-value group과 chart 사이의 남는 여백이 두드러지지 않도록 chart-on 고정폭을 필요한 만큼만 잡는다. 기준 폭은 chart on 108pt, chart off 62pt, chart 42pt로 둔다.
- Disk 메뉴바 항목은 leading icon과 read/write 두 줄 값을 유지하되, icon-label-value group과 chart 사이의 남는 여백이 두드러지지 않도록 chart-on 고정폭을 필요한 만큼만 잡는다. 기준 폭은 chart on 108pt, chart off 62pt, chart 42pt로 둔다.
- 계층형 secondary 값이 없는 지표에는 secondary value 표시 설정을 노출하지 않는다.
- 각 항목은 해당 지표를 나타내는 system icon을 함께 표시한다.
- 메뉴바와 manager/settings preview에 표시되는 system icon은 multicolor/palette 렌더링을 쓰지 않고 단색 template/tint 렌더링으로 표시한다.
- 메뉴바 항목에는 작은 sparkline chart를 표시할 수 있다. 차트 역시 고정폭 status item 영역 안에 렌더링한다.
- 메뉴바 sparkline은 배경색 변화에 흔들리지 않도록 지표별 accent color 대신 시스템 단색 foreground로 렌더링한다.
- 메뉴바 sparkline은 데이터 선보다 약한 baseline/midline grid를 포함해 스케일을 읽을 수 있게 한다.
- Network 메뉴바 sparkline은 download와 upload를 두 개의 선으로 렌더링한다.
- Disk 메뉴바 sparkline은 read와 write를 두 개의 선으로 렌더링한다.
- 다중선 sparkline은 같은 단색 계열을 유지하고, 두 번째 선은 투명도 또는 dash로 구분한다.
- metric별 설정에서 menu bar chart 표시 여부를 켜고 끌 수 있다.
- Network/Disk처럼 다중선 메뉴바 chart가 있는 항목은 단일선 지표보다 넓은 chart 영역을 확보하되, 메뉴바에서 텍스트보다 chart가 과도하게 커 보이면 안 된다. 이 폭은 빈 여백이 아니라 실제 plot 영역이어야 한다.
- 값이 `unsupported` 또는 `unavailable`인 항목은 메뉴바에서 숨길 수 있다.
- 사용자가 settings window의 metric tab에서 메뉴바 표시 항목을 선택할 수 있다.
- 네트워크와 디스크 단위는 읽기 쉬운 단위로 자동 축약한다.
- byte-rate 0 값은 `Zero KB/s`처럼 단어로 표시하지 않고 `0 KB/s`처럼 숫자로 표시한다.

## 19. 팝오버 UI

팝오버는 선택한 메뉴바 지표의 현재 snapshot과 최근 그래프를 우선 표시한다. 필요한 경우 다른 지표 요약으로 이동할 수 있지만, MVP에서는 클릭한 지표의 detail popover를 기본으로 한다.

메뉴 항목 클릭 인터랙션:

- 사용자가 CPU/GPU/Temperature/Network/Disk 메뉴바 항목을 클릭하면 해당 지표 전용 popover를 연다.
- popover는 항상 하나만 열린다.
- popover가 열린 직후 popover window가 key window가 되어 버튼, segmented control, scroll view가 즉시 상호작용 가능해야 한다.
- 외부 앱, desktop, 설정 창 등 popover 바깥 영역을 클릭하면 popover는 닫힌다.
- popover는 열려 있는 동안 ring buffer의 최신 sample을 계속 반영한다.
- popover는 클릭한 지표의 히스토리만 우선 표시하고, 다른 지표의 전체 대시보드로 전환하지 않는다.
- popover 상단에는 지표 icon, 지표명, collector status, manager window 버튼을 둔다.
- popover 본문에는 현재값, 최근 측정 기간, sample 수, live chart, min/max/avg 요약, 지표별 세부 정보를 둔다.
- popover는 고정 높이를 강제하지 않는다. content fitting height가 최대 높이보다 작으면 내용 높이까지 줄어들고, 최대 높이를 넘으면 최대 높이에서 내부 스크롤한다.
- popover 기본 폭은 460pt, 최소 높이는 280pt, 최대 높이는 620pt로 제한한다.
- chart는 ring buffer timestamp 기준 최근 데이터를 사용하며, 샘플 간격이 변해도 배열 인덱스만으로 시간을 설명하지 않는다.
- chart 영역은 padding을 작게 유지하고 축 label은 오른쪽 좁은 gutter 안에 배치한다.
- chart 좌우 padding은 최소화한다. CPU, Network, Disk처럼 사용자가 추이를 빠르게 읽어야 하는 지표에서 plot 영역보다 padding/gutter가 두드러져 보이면 안 된다.
- chart grid는 데이터보다 진하게 보이면 안 되며, series line과 legend가 우선 읽혀야 한다.
- network와 disk처럼 방향이 둘인 지표는 download/upload 또는 read/write를 같은 chart 안에 별도 series로 표시한다.
- CPU는 total usage를 주 series로 표시하고 P-core/E-core 평균은 세부 정보와 현재 코어 목록으로 표시한다.
- Temperature는 CPU/GPU/SoC 온도를 별도 series로 표시하되, 불확실하거나 없는 값은 표시하지 않는다.
- 값이 `Unsupported` 또는 `Unavailable`이면 chart 영역은 비어 있음을 명시하고 마지막 상태와 사유를 보여준다.

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
- 각 detail popover는 icon, 현재값, status badge, live chart, min/max/avg 요약, 세부 정보 row를 포함한다.
- manager window로 이동하는 버튼을 제공한다.
- popover의 manager/settings 버튼은 window를 만들고 앞으로 가져오는 동작까지 보장해야 한다.

## 20. Manager Window

`mystats`는 메뉴바 항목을 켜고 끄는 manager window를 제공한다. 메뉴바 popover 내부에서 window open이 무반응처럼 보이지 않도록, manager window는 AppKit window controller가 하나의 `NSWindow`를 소유하고 SwiftUI 설정 화면을 호스팅한다.

manager/settings window 기능:

- CPU, GPU, Temperature, Network, Disk 메뉴바 항목 on/off
- metric별 menu item detail 설정
  - 계층형 secondary value가 있는 지표의 secondary 표시
  - menu bar chart 표시
  - popover detail section 표시
- Temperature, GPU처럼 계층형 secondary value가 없는 지표의 metric tab에는 secondary value 설정을 노출하지 않는다.
- 각 항목의 고정폭 메뉴바 폭 표시
- 샘플링 모드 설정
- unknown sensor, VPN interface, external disk, temperature unit 설정
- 시작 시 자동 실행 설정
- 앱 종료 버튼

manager/settings window UI 정책:

- macOS 표준 utility/settings window처럼 동작한다.
- settings window header의 아이콘은 앱 번들 아이콘과 일치해야 한다.
- 설정 화면은 sidebar checkbox 목록이 아니라 `General`, `CPU`, `GPU`, `Temperature`, `Network`, `Disk` 탭으로 구성한다.
- metric tab에는 해당 metric의 on/off와 상세 표시 설정을 함께 둔다.
- 항목별 toggle은 즉시 저장한다.
- live chart와 지표 상세 정보는 각 metric popover가 담당한다. manager window는 설정 변경 중 응답성을 우선한다.
- 메뉴바에서 모든 지표를 끄는 것은 허용하지 않는다.
- manager/settings window는 같은 창을 재사용하며 window title은 `mystats Settings`로 둔다.
- 창이 이미 열려 있으면 새 창을 중복 생성하지 않고 기존 창을 앞으로 가져온다.
- 초기 개발 단계에서는 앱 실행 시 설정 창을 함께 열어 QA와 설정 접근성을 보장한다.
- 앱 번들의 `Info.plist`는 `LSUIElement=true`를 사용해 Dock 노출을 막는다.
- 설정 창은 Dock 아이콘 없이도 앞으로 가져올 수 있어야 하며, 앱 activation policy는 `.accessory`를 유지한다.
- status item 목록은 settings change 시 동기화하고, metric sample change 시 현재 status item label만 갱신한다.

## 21. 설정

설정 저장은 `UserDefaults`로 충분하다.

```swift
struct AppSettings: Codable {
    var menuBarItems: [MenuBarItem]
    var metricItemSettings: [MenuBarItem: MetricItemSettings]
    var samplingMode: SamplingMode
    var showUnknownSensors: Bool
    var includeVPNInterfaces: Bool
    var includeExternalDisks: Bool
    var launchAtLogin: Bool
    var temperatureUnit: TemperatureUnit
}

struct MetricItemSettings: Codable {
    var showsSecondaryValue: Bool
    var showsMenuBarSparkline: Bool
    var showsPopoverDetails: Bool
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
- menu item visibility QA는 CPU/GPU/Temperature/Network/Disk를 각각 끈 상태와 다시 켠 상태를 모두 확인한다.
- 마지막으로 남은 menu item은 끌 수 없고, 이 보호 동작은 QA에서 별도로 확인한다.
- 메뉴바 값 변화 중 항목 폭이 변하지 않는지 확인
- chart 표시 옵션 on/off 상태를 모두 캡처해 chart off 상태에서 메뉴바 항목 폭이 줄고, chart on 상태에서 각 지표의 sparkline이 표시되는지 확인
- Network/Disk는 메뉴바와 popover visual QA에서 두 방향 선이 모두 보이는지 확인
- popover visual QA는 각 metric의 fitting height가 최대 높이를 넘지 않는지, 내용이 적은 metric이 최대 높이로 고정되지 않는지 확인한다.
- popover의 chart가 ring buffer와 함께 갱신되는지 확인
- manager/settings window를 열었을 때 앱 CPU가 idle에 가깝게 안정되는지 확인
- manager/settings window의 종료 버튼이 앱 프로세스를 종료하는지 확인
- DEBUG 빌드는 `--render-qa=<path>`로 status item chart on/off와 metric popover chart PNG를 생성할 수 있다. 이 경로는 화면 캡처 권한 문제로 전체화면 screenshot이 불가능한 환경에서 visual regression 확인용으로만 사용한다.

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
