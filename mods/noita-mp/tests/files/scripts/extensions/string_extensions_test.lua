dofile("mods/noita-mp/files/scripts/init/init_.lua")

local lu = require("luaunit")

TestStringExtensions = {}

function TestStringExtensions:setUp()
    print("\nsetUp")
end

function TestStringExtensions:tearDown()
    print("tearDown\n")
end

function TestStringExtensions:testExtendAndCutStringToLength()
    lu.assertErrorMsgEquals("var is not a string.", string.ExtendOrCutStringToLength, 1)
    lu.assertErrorMsgEquals("length is not a number.", string.ExtendOrCutStringToLength, "var", "length")
    lu.assertErrorMsgContains(
        "char is not a character. string.len(char) > 1 = ",
        string.ExtendOrCutStringToLength,
        "var",
        1,
        "character"
    )

    local expected = "12345"
    local actual = string.ExtendOrCutStringToLength("12345678910", 5, " ")
    lu.assertEquals(actual, expected)

    local expected2 = "1234      "
    local actual2 = string.ExtendOrCutStringToLength("1234", 10, " ")
    lu.assertEquals(actual2, expected2)
end

os.exit(lu.LuaUnit.run())
