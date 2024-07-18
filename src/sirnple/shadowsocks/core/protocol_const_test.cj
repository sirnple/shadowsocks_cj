package sirnple.shadowsocks.core

from std import unittest.*
from std import unittest.testmacro.*

@Test[authMethod in [METHOD_NOAUTH, METHOD_GSSAPI, METHOD_USERPASS]]
func test_support_auth(authMethod: UInt8) {
    match (tryProcessSocks5AuthRequest([SOCKS_VERSION_5, 0x01, authMethod])) {
        case Some(authResponse) => 
            @Assert(authResponse.size == 2)
            @Assert(authResponse[0] == SOCKS_VERSION_5)
            @Assert(authResponse[1]== authMethod)
        case None => @Assert(false)
    }
}

@Test
func test_pack_ss_local_send_first_pack_ipv4() {
    let firstPacketData = [1u8]
    let port = [0u8, 0u8]

    let ipv4 = [127u8, 0u8, 0u8, 1u8]
    let dstAddrIpv4 = DstAddr(ATYP_IPv4, ipv4, port)
    let firstPacketIpv4 = packSsLocalSendFirstSsPacket(dstAddrIpv4, firstPacketData)
    @Assert(firstPacketIpv4 == [ATYP_IPv4] + ipv4 + port + firstPacketData)
}

@Test
func test_pack_ss_local_send_first_pack_ipv6() {
    let firstPacketData = [1u8]
    let port = [0u8, 0u8]

    let ipv6 = [244u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 1u8]
    let dstAddrIpv6 = DstAddr(ATYP_IPv6, ipv6, port)
    let firstPacketIpv6 = packSsLocalSendFirstSsPacket(dstAddrIpv6, firstPacketData)
    @Assert(firstPacketIpv6 == [ATYP_IPv6] + ipv6 + port + firstPacketData)
}

@Test
func test_pack_ss_local_send_first_pack_domainname() {
    let firstPacketData = [1u8]
    let port = [0u8, 0u8]

    let domain = [1u8, 2u8, 3u8, 4u8, 5u8, 6u8, 7u8, 8u8, 9u8, 10u8, 11u8, 12u8, 13u8, 14u8, 15u8, 16u8]
    let dstAddrDomain = DstAddr(ATYP_DOMAINNAME, domain, port)
    let firstPacketDomain = packSsLocalSendFirstSsPacket(dstAddrDomain, firstPacketData)
    @Assert(firstPacketDomain == [ATYP_DOMAINNAME, UInt8(domain.size)] + domain + port + firstPacketData)
}
@Test
func test_pack_ss_local_send_first_pack_invalid_atyp() {
    let firstPacketData = [1u8]
    let ipv4 = [127u8, 0u8, 0u8, 1u8]
    let dstAddrIpv4 = DstAddr(0xFFu8, ipv4, [0u8, 0u8])
    try {
        packSsLocalSendFirstSsPacket(dstAddrIpv4, firstPacketData)
    } catch (e: Exception) {
        @Assert(e.message == "Should never happen")
    }
}