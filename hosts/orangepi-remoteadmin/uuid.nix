{ lib, ... }:
with builtins;
with lib;
let
  nilUUID = {
    bytes = [ 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ];
    outPath = "00000000-0000-0000-0000-000000000000";
    version = 0;
    variant = 0;
  };

  toHex2 = x: fixedWidthNumber 2 (toLower (toHexString x));

  hexStringToUUID = x:
    assert stringLength x >= 128 / 8;  # only using the prefix is ok
    (substring 0 8 x) + "-" + (substring 8 4 x) + "-" + (substring 12 4 x)
      + "-" + (substring 16 4 x) + "-" + (substring 20 12 x);
    
  formatBinaryUUID = x:
    assert length x == 16;
    hexStringToUUID (concatMapStrings toHex2 x);

  fromHexDigit = x:
    let x2 = toLower x; in
    if x2 == "a" then 10
    else if x2 == "b" then 11
    else if x2 == "c" then 12
    else if x2 == "d" then 13
    else if x2 == "e" then 14
    else if x2 == "f" then 15
    else toInt x;

  fromHex2 = x:
    assert stringLength x == 2;
    let x2 = stringToCharacters x; in
    16*(fromHexDigit (elemAt x2 0)) + (fromHexDigit (elemAt x2 1));

  parseUUID = x:
    let
      mbyte = "([a-fA-F0-9]{2,2})";
      mbyte2 = mbyte+mbyte;
      mbyte4 = mbyte2+mbyte2;
      mbyte6 = mbyte4+mbyte2;
      parsed = match "${mbyte4}-${mbyte2}-${mbyte2}-${mbyte2}-${mbyte6}[ \t\r\n]*" x;
      bytes = map fromHex2 parsed;
    in if parsed == null
    then throw "invalid UUID: ${toString x}"
    else bytes;

  toUUID = x:
    let
      bytes = if isList x && length x == 16
        then x
        else if isAttrs x && x ? bytes && isList x.bytes && length x.bytes == 16
        then x.bytes
        else if isString x  # && stringLength x == stringLength nilUUID.outPath
        then parseUUID x
        else throw "invalid UUID: ${toString x}";
      variantNibble = (elemAt bytes 8) / 16;
      variant = if variantNibble < 8 then 0
        else if variantNibble < 12 then 1
        else if variantNibble < 14 then 2
        else 3;  # reserved value
    in {
      inherit bytes variant;
      outPath = formatBinaryUUID bytes;
      version = (elemAt bytes 6) / 16;
    };

  # We have to replace some bits. This is how it would work for actual version-5 UUIDs:
  # $ uuidgen -N "" --sha1 -n 00000000-0000-0000-0000-000000000000
  # e129f27c-5103-5c5c-844b-cdf0a15e160d
  #                    ^ variant
  #               ^ version
  # $ echo -ne '\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0' | sha1sum
  # e129f27c5103bc5cc44bcdf0a15e160d445066ff
  setVersionAndVariant = version: variant: variantMask: uuid:
    let modify = i: byte:
      if i == 6 then (bitAnd byte 15) + (version*16)
      else if i == 8 then (bitAnd byte (15+16*variantMask)) + (variant*16)
      else byte;
    in imap0 modify (toUUID uuid).bytes;

  # I would have implemented actual version-5 UUIDs but Nix doesn't allow binary
  # data in strings. We could still do it with uuidgen and import-from-derivation
  # but we don't have to be compatible - so let's rather be fast.
  # Thus, this is *in spirit but not actually* similar to the following command:
  #   uuidgen -n namespace --sha1 -N name
  namespacedUUIDNonStandard = namespace: name:
    let
      hash = hashString "sha1" ((toUUID namespace).outPath + name);
      uuidTmp = toUUID (hexStringToUUID hash);
    in toUUID (setVersionAndVariant 5 8 3 uuidTmp);

  uuidTests =
    let expectFailure = x: !(tryEval x).success; in
    assert toHex2 0 == "00";
    assert toHex2 18 == "12";
    assert toHex2 255 == "ff";
    assert expectFailure (toHex2 (-1));
    assert expectFailure (toHex2 256);
    assert fromHex2 "00" == 0;
    assert fromHex2 "28" == 16*2 + 8;
    assert fromHex2 "ab" == 16*10 + 11;
    assert fromHex2 "CD" == 16*12 + 13;
    assert fromHex2 "eF" == 16*14 + 15;
    assert expectFailure (fromHex2 "0");
    assert expectFailure (fromHex2 "000");
    #assert expectFailure (fromHex2 "-1");
    assert nilUUID == toUUID nilUUID.bytes;
    assert nilUUID == traceValSeq (toUUID nilUUID.outPath);
    let ns = "15432917-1c3e-4092-a3c0-f10f9333066f"; uuid = namespacedUUIDNonStandard ns "abc"; in
    assert toString (toUUID ns) == ns;
    assert traceSeq uuid (uuid.version == 5);
    assert uuid.variant == 1;
    assert toString uuid == "70a52275-cd55-5388-a5b1-55ac84b64da1";
    { name = "ok"; };
in {
  inherit nilUUID toUUID namespacedUUIDNonStandard uuidTests;
}
