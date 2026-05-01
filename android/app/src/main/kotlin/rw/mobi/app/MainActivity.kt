package rw.mobi.app

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.mobi.ledger.LedgerApi
import com.mobi.ledger.LedgerApiImpl

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup Pigeon LedgerBridge
        LedgerApi.setUp(flutterEngine.dartExecutor.binaryMessenger, LedgerApiImpl(this))
    }
}
