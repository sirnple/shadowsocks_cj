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