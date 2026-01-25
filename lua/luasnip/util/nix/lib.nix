let
    types = {
        ok = "Ok";
        error = "Error";
    };
    assert_prefix = snip:
        if snip ? prefix
        then
            if builtins.isString snip.prefix || (builtins.isList snip.prefix && builtins.all builtins.isString snip.prefix)
            then {type = types.ok;}
            else {
                type = types.error;
                message = "Property: 'prefix' must be of type: 'string' or 'string list'.";
            }
        else {
            type = types.error;
            message = "Property: 'prefix' not defined.";
        };
    assert_body = snip:
        if snip ? body
        then
            if builtins.isString snip.body || (builtins.isList snip.body && builtins.all builtins.isString snip.body)
            then {type = types.ok;}
            else {
                type = types.error;
                message = "Property: 'body' must be of type: 'string' or 'string list'.";
            }
        else {
            type = types.error;
            message = "Property: 'body' not defined.";
        };
    assert_description = snip:
        if ! snip ? description || builtins.isString snip.description
        then {type = types.ok;}
        else {
            type = types.error;
            message = "Property: 'description' must be of type: 'string' or 'null'.";
        };
    assert_scope = snip:
        if ! snip ? scope || builtins.isString snip.scope
        then {type = types.ok;}
        else {
            type = types.error;
            message = "Property: 'scope' must be of type: 'string' or 'null'.";
        };
    assert_no_outliers = snip: let
        known_attrs = ["prefix" "body" "description" "scope"];
        extra = builtins.filter (n: ! (builtins.elem n known_attrs)) (builtins.attrNames snip);
    in
        if extra == []
        then {type = types.ok;}
        else {
            type = types.error;
            message = "Unknown property: '${builtins.elemAt extra 0}'.";
        };

    # // @param snip Snippet
    # // @return Result<Snippet, { type = "Error", message }>
    parse_snippet = snip: let
        valid_prefix = assert_prefix snip;
        valid_body = assert_body snip;
        valid_description = assert_description snip;
        valid_scope = assert_scope snip;
        valid_snip = assert_no_outliers snip;
    in
        if valid_prefix.type == types.error
        then valid_prefix
        else if valid_body.type == types.error
        then valid_body
        else if valid_description.type == types.error
        then valid_description
        else if valid_scope.type == types.error
        then valid_scope
        else if valid_snip.type == types.error
        then valid_snip
        else snip;
in {
    # // @type Snippet {
    # //     prefix string | string[]
    # //     body string | string[]
    # //     description string?
    # // }

    # // @param filepath path
    # // @return {
    # //    snippet_name = Result<Snippet, { type = "Error", message }>,
    # //    ...
    # // }
    parse_file = filepath: let
        filename = builtins.baseNameOf filepath;
        expr = import filepath;
    in
        if builtins.typeOf expr != "set"
        then {
            type = types.error;
            message = "File: '${filename}' must be of type: 'set' aka '{ }'.";
        }
        else let
            result = builtins.mapAttrs (name: value: parse_snippet value) expr;
        in
            result;
    parse_set = filename: expr:
        if builtins.typeOf expr != "set"
        then {
            type = types.error;
            message = "File: '${filename}' must be of type: 'set' aka '{ }'.";
        }
        else let
            result = builtins.mapAttrs (name: value: parse_snippet value) expr;
        in
            result;
}
