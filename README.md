# CBWapper
CoreBluetoothって非Sendableだし、async じゃないし、そういうのをいい感じに最新化したいよね



## 使用方法(簡易版)

### スキャン
まず、IPeripheralScannerの実体(Transporter)を取得します。

startScanを呼ぶことでペリフェラル(センサ、アドバタイズとも言う)のスキャンを開始します。
スキャンしたペリフェラルは、peripheralStreamで配信されます。

### 接続
接続にはIConnectorを使用します。これもTransporterが実装しています。
peripheralStreamから取得したPeripheralを使用して接続してください。

接続メソッドは2種類あり、使用後は自動的に後始末(切断)するものと、
明示的に切断しなければならないものがあります。
特別な理由がない限り前者を使用することを推奨します。

### 通信
ペリフェラルと接続すると、ICommunicatorを受け取るので
これを使用して通信してください。



## protocolの解説
### IPeripheralScanner
ペリフェラルのスキャンを担当するプロトコルです。Transporterが実装しています。

- スキャンの開始・終了
スキャンを行う場合は startScan(withServices:options:)
停止する場合は stopScan() を呼んでください。
現在スキャン中かどうかは isScanning プロパティで確認できます。

- Bluetoothの状態
Bluetoothが使用可能かどうかは currentState で確認できます。
状態に変化があった場合は stateStream() で配信します。

- スキャン結果の配信
スキャンしたペリフェラルは peripheralStream() で配信されます。
ペリフェラルは CBPeripheral を DiscoveredPeripheralでラップして返します。
これはCoreBluetoothを隠蔽したいことと、Sendableに準拠するためです。



