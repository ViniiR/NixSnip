let
    types = {
        ok = "Ok";
        error = "Error";
    };
    snippet = {
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
    };

    # // @param snip Snippet
    # // @return Result<Snippet, { type = "Error", message }>
    parse_snippet = snip: let
        valid_prefix = snippet.assert_prefix snip;
        valid_body = snippet.assert_body snip;
        valid_description = snippet.assert_description snip;
        valid_scope = snippet.assert_scope snip;
        valid_snip = snippet.assert_no_outliers snip;
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

    manifest = {
        assert_name = manifest:
            if manifest ? name
            then
                if builtins.isString manifest.name
                then {type = types.ok;}
                else {
                    type = types.error;
                    message = "Manifest property: 'name' must be of type: 'string'.";
                }
            else {
                type = types.error;
                message = "Manifest property: 'name' not defined.";
            };
        assert_description = manifest:
            if manifest ? description
            then
                if builtins.isString manifest.description
                then {type = types.ok;}
                else {
                    type = types.error;
                    message = "Manifest property: 'description' must be of type: 'string' or 'null'.";
                }
            else {type = types.ok;};
        assert_version = manifest:
            if manifest ? version
            then
                if builtins.isString manifest.version
                then {type = types.ok;}
                else {
                    type = types.error;
                    message = "Manifest property: 'version' must be of type: 'string' or 'null'.";
                }
            else {type = types.ok;};
        assert_categories = manifest:
            if manifest ? categories
            then
                if builtins.isList manifest.categories && builtins.all builtins.isString manifest.categories
                then {type = types.ok;}
                else {
                    type = types.error;
                    message = "Manifest property: 'categories' must be of type: 'string list' or 'null'.";
                }
            else {type = types.ok;};
        assert_contributes = manifest: let
            assert_snippets = manifest: let
                # NOTE: these internal error messages must be modified in lua
                assert_language = snip:
                    if snip ? language
                    then
                        if builtins.isString snip.language || (builtins.isList snip.language && builtins.all builtins.isString snip.language)
                        then snip
                        else {
                            type = types.error;
                            message = ".language' must be of type 'string' or 'string list'.";
                        }
                    else {
                        type = types.error;
                        message = ".language' not defined.";
                    };
                assert_path = snip:
                    if snip ? path
                    then
                        if builtins.isPath snip.path
                        then snip
                        else {
                            type = types.error;
                            message = ".path' must be of type 'path'.";
                        }
                    else {
                        type = types.error;
                        message = ".path' not defined.";
                    };
                list = builtins.map (
                    snip: let
                        valid_language = assert_language snip;
                        valid_path = assert_path snip;
                    in
                        if valid_language ? type && valid_language.type == types.error
                        then valid_language
                        else if valid_path ? type && valid_path.type == types.error
                        then valid_path
                        else snip
                )
                manifest.contributes.snippets;
            in
                if builtins.all (e: !e ? type) list
                then list
                else {
                    type = types.error;
                    message = "Manifest property: 'contributes.snippets[i]' internal error message available.";
                    content = list;
                };
        in
            if manifest ? contributes
            then
                if builtins.typeOf manifest.contributes == "set"
                then
                    if manifest.contributes ? snippets
                    then
                        if
                            builtins.isList manifest.contributes.snippets
                            && builtins.all (snip: builtins.typeOf snip == "set") manifest.contributes.snippets
                        then assert_snippets manifest
                        else {
                            type = types.error;
                            message = "Manifest property: 'contributes.snippets' must be of type 'set list' aka '[{ }]'.";
                        }
                    else {
                        type = types.error;
                        message = "Manifest property: 'contributes.snippets' not defined.";
                    }
                else {
                    type = types.error;
                    message = "Manifest property: 'contributes' must be of type: 'set' aka '{ }'.";
                }
            else {
                type = types.error;
                message = "Manifest property: 'contributes' not defined.";
            };
        assert_no_outliers = snip: let
            known_attrs = ["name" "displayName" "description" "version" "publisher" "engines" "categories" "contributes"];
            extra = builtins.filter (n: ! (builtins.elem n known_attrs)) (builtins.attrNames snip);
        in
            if extra == []
            then {type = types.ok;}
            else {
                type = types.error;
                message = "Unknown Manifest property: '${builtins.elemAt extra 0}'.";
            };
    };
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
    # does not enforce properties
    parse_manifest = filepath: let
        filename = builtins.baseNameOf filepath;
        expr = import filepath;
    in
        if builtins.typeOf expr != "set"
        then {
            type = types.error;
            message = "Manifest: '${filename}' must be of type: 'set' aka '{ }'.";
        }
        else expr;
    # enforced by
    # https://github.com/microsoft/vscode-extension-samples/blob/main/snippet-sample/package.json
    parse_manifest_secure = filepath: let
        filename = builtins.baseNameOf filepath;
        expr = import filepath;
    in
        if builtins.typeOf expr != "set"
        then {
            type = types.error;
            message = "Manifest: '${filename}' must be of type: 'set' aka '{ }'.";
        }
        else let
            valid_name = manifest.assert_name expr;
            valid_description = manifest.assert_description expr;
            valid_version = manifest.assert_version expr;
            valid_categories = manifest.assert_categories expr;
            valid_contributes = manifest.assert_contributes expr;
            valid_manifest = manifest.assert_no_outliers expr;
        in
            if valid_name.type == types.error
            then valid_name
            else if valid_description.type == types.error
            then valid_description
            else if valid_version.type == types.error
            then valid_version
            else if valid_categories.type == types.error
            then valid_categories
            else if valid_contributes ? type && valid_contributes.type == types.error
            then valid_contributes
            else if valid_manifest.type == types.error
            then valid_manifest
            else expr;
}
