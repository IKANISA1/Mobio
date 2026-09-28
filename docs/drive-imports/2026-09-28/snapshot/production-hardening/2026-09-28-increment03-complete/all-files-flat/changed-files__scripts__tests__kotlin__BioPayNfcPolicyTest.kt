package rw.mobi.app
import java.time.Instant

fun main() {
    var passed = 0
    fun scenario(name: String, block: () -> Unit) { block(); passed++; println("PASS: $name") }
    val now=1_800_000_000_000L; val elapsed=1000L
    fun expiry(offset:Long)=Instant.ofEpochMilli(now+offset).toString()
    fun hex(value:String)=value.chunked(2).map{it.toInt(16).toByte()}.toByteArray()
    val state=BioPayNfcPolicy.prepare("tel:fixture",expiry(60000L),now,elapsed)!!
    scenario("live interval") { check(BioPayNfcPolicy.active(state,now+1,elapsed+1)) }
    scenario("wall expiry exact boundary") { check(!BioPayNfcPolicy.active(state,now+60000,elapsed+60000)) }
    scenario("wall clock rollback") { check(!BioPayNfcPolicy.active(state,now-1,elapsed+1)) }
    scenario("monotonic expiry despite wall delay") { check(!BioPayNfcPolicy.active(state,now+1,elapsed+60000)) }
    scenario("monotonic reset") { check(!BioPayNfcPolicy.active(state,now+1,0)) }
    scenario("process death denies persisted payload") { check(!BioPayNfcPolicy.active(state.copy(instance="old-process"),now+1,elapsed+1)) }
    scenario("disabled") { check(!BioPayNfcPolicy.active(state.copy(enabled=false),now+1,elapsed+1)) }
    scenario("missing payload") { check(!BioPayNfcPolicy.active(state.copy(payload=null),now+1,elapsed+1)) }
    scenario("oversized UTF8 payload") { check(BioPayNfcPolicy.prepare("é".repeat(116),expiry(60000),now,elapsed)==null) }
    scenario("missing expiry") { check(BioPayNfcPolicy.prepare("tel:fixture",null,now,elapsed)==null) }
    scenario("malformed expiry") { check(BioPayNfcPolicy.prepare("tel:fixture","invalid",now,elapsed)==null) }
    scenario("expired preparation") { check(BioPayNfcPolicy.prepare("tel:fixture",expiry(0),now,elapsed)==null) }
    scenario("duration capped") { check(BioPayNfcPolicy.prepare("tel:fixture",expiry(900000),now,elapsed)!!.expiresAtMillis == now+300000) }
    scenario("deadline overflow denied") { check(BioPayNfcPolicy.prepare("tel:fixture",expiry(60000),now,Long.MAX_VALUE)==null) }
    scenario("exact SELECT with Le") { check(BioPayNfcPolicy.isSelectAid(hex("00A4040007F04D4F42494F0000"))) }
    scenario("exact SELECT without Le") { check(BioPayNfcPolicy.isSelectAid(hex("00A4040007F04D4F42494F00"))) }
    scenario("embedded AID not SELECT") { check(!BioPayNfcPolicy.isSelectAid(hex("00A4040009FFFFF04D4F42494F0000"))) }
    scenario("trailing bytes rejected") { check(!BioPayNfcPolicy.isSelectAid(hex("00A4040007F04D4F42494F000001"))) }
    scenario("wrong length byte rejected") { check(!BioPayNfcPolicy.isSelectAid(hex("00A4040008F04D4F42494F0000"))) }
    scenario("null SELECT rejected") { check(!BioPayNfcPolicy.isSelectAid(null)) }
    println("$passed JVM policy scenarios passed. No Android framework, NFC hardware or signed-app tests ran.")
}
