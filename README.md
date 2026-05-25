# CBWapper
CoreBluetoothって非Sendableだし、async じゃないし、そういうのをいい感じに最新化したいよね



## 使用方法

### スキャン
まず、IPeripheralScannerの実体を取得します。Transporterですね。

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




