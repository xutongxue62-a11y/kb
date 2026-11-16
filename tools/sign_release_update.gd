extends SceneTree
func _initialize() -> void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=3:
        push_error("Expected private key, payload JSON, signed output path");quit(1);return
    var key:=CryptoKey.new()
    if key.load(args[0])!=OK: quit(1);return
    var raw:=FileAccess.get_file_as_string(args[1])
    if typeof(JSON.parse_string(raw))!=TYPE_DICTIONARY: quit(1);return
    var signature:=Crypto.new().sign(HashingContext.HASH_SHA256,raw.sha256_buffer(),key)
    var output:=FileAccess.open(args[2],FileAccess.WRITE)
    if output==null: quit(1);return
    output.store_string(JSON.stringify({"payload":raw,"signature":Marshalls.raw_to_base64(signature)},"  "));output.close()
    print("Signed content-update manifest; private key was not copied")
    quit()
