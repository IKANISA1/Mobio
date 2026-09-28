import com.momobio.app.CollectorPolicy
import com.momobio.app.CollectorTransportPolicy
import com.momobio.app.CollectorLease
import java.io.File
import java.nio.file.Files
import java.util.concurrent.Executors

fun main(args: Array<String>) {
    if (args.size == 2 && args[0] == "--lease-probe") {
        val acquired = CollectorLease.withLease(File(args[1])) { true } == true
        kotlin.system.exitProcess(if (acquired) 0 else 75)
    }
    var count=0
    fun scenario(name:String, test:()->Unit) { test();count++;println("PASS: $name") }
    val p=CollectorPolicy.fromCsv("fixture-v1","MTN, MobileMoney","You have received,Merchant payment")
    scenario("configured fixture") { check(p.configured) }
    scenario("no default collection policy") { check(!CollectorPolicy.fromCsv("","","").configured) }
    scenario("allowed sender and receipt marker") { check(p.accepts("MTN","You have received 2000 RWF",1)) }
    scenario("unknown sender excluded") { check(!p.accepts("Friend","You have received 2000 RWF",1)) }
    scenario("marketing excluded") { check(!p.accepts("MTN","Buy our new bundle",1)) }
    scenario("case normalization") { check(p.accepts(" mtn ","YOU HAVE RECEIVED 2000 RWF",1)) }
    scenario("zero timestamp excluded") { check(!p.accepts("MTN","You have received 2 RWF",0)) }
    scenario("oversized UTF8 excluded") { check(!p.accepts("MTN","You have received"+"🌍".repeat(2500),1)) }
    scenario("nul excluded") { check(!p.accepts("MTN","You have received\u0000",1)) }
    scenario("too-short marker configuration rejected") { check(!CollectorPolicy.fromCsv("v1","MTN","a").configured) }
    for (url in listOf("https://fixture.invalid","https://fixture.invalid/","https://fixture.invalid:443")) {
        scenario("secure origin $url") { check(CollectorTransportPolicy.validEndpoint(url)) }
    }
    for (url in listOf("http://fixture.invalid","https://user:secret@fixture.invalid","https://fixture.invalid/path",
        "https://fixture.invalid?query=1","https://fixture.invalid#frag","https://fixture.invalid:80","not a url","https:///")) {
        scenario("reject origin $url") { check(!CollectorTransportPolicy.validEndpoint(url)) }
    }
    scenario("retry-after seconds") { check(CollectorTransportPolicy.retryAfterMillis("120",0)==120000L) }
    scenario("retry-after invalid") { check(CollectorTransportPolicy.retryAfterMillis("bad",0)==null) }
    scenario("retry-after negative") { check(CollectorTransportPolicy.retryAfterMillis("-2",0)==null) }
    scenario("retry-after date") { check(CollectorTransportPolicy.retryAfterMillis("Thu, 01 Jan 1970 00:02:00 GMT",0)==120000L) }
    scenario("bounded exponent") { check(CollectorTransportPolicy.backoffMillis(Int.MAX_VALUE)<=4500000L) }
    scenario("retry-after controls minimum delay") { check(CollectorTransportPolicy.backoffMillis(1,120000,0.0)==120000L) }
    scenario("invalid jitter bounded") { check(CollectorTransportPolicy.backoffMillis(1,null,Double.NaN)==33750L) }
    scenario("consent invalidated by changed senders") { check(p.fingerprint != p.copy(allowedSenders=setOf("Other")).fingerprint) }
    scenario("consent invalidated by changed markers") { check(p.fingerprint != p.copy(receiptMarkers=setOf("New receipt")).fingerprint) }
    scenario("policy set order does not change consent") { check(p.fingerprint == p.copy(allowedSenders=p.allowedSenders.reversed().toSet()).fingerprint) }
    scenario("newline sender policy rejected") { check(!p.copy(allowedSenders=setOf("MTN\nFake")).configured) }
    scenario("newline marker policy rejected") { check(!p.copy(receiptMarkers=setOf("Receipt\nFake")).configured) }
    val dir=Files.createTempDirectory("collector-lease-").toFile();val file=File(dir,"sync.lock")
    fun child(): Int {
        val process=ProcessBuilder(File(System.getProperty("java.home"),"bin/java").path,
            "-jar",System.getProperty("java.class.path"),"--lease-probe",file.path).redirectErrorStream(true).start()
        if (!process.waitFor(10,java.util.concurrent.TimeUnit.SECONDS)) {
            process.destroyForcibly();error("Lease child timed out")
        }
        return process.exitValue()
    }
    try {
        scenario("OS lease blocks a separate JVM process") {
            CollectorLease.withLease(file) { check(child() == 75) }
        }
        scenario("separate JVM can acquire after release") { check(child() == 0) }
        scenario("actual OS lease blocks simultaneous holder") {
            CollectorLease.withLease(file) {
                val executor=Executors.newSingleThreadExecutor()
                try { check(executor.submit<Boolean> { CollectorLease.withLease(file) { true } == null }.get()) }
                finally { executor.shutdownNow() }
            }
        }
        scenario("lease releases after exception") {
            try { CollectorLease.withLease(file) { error("fixture") } } catch (_:IllegalStateException) { }
            check(CollectorLease.withLease(file) { true } == true)
        }
        scenario("lease repeat safe") { repeat(20) { check(CollectorLease.withLease(file) { true } == true) } }
    } finally { dir.deleteRecursively() }
    println("Collector policy/OS lease: $count scenarios passed (not Android device acceptance).")
}
