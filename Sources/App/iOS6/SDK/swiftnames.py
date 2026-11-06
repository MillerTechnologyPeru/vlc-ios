#!/usr/bin/env python3
"""Writes Swift's names for the methods and properties of generated wrappers.

Swift-iOS6's objcgen.py names a wrapper's members after their Objective-C
selectors (`presentViewController(_:animated:completion:)`,
`UIColor.whiteColor()`), and Swift renames them
(`present(_:animated:completion:)`, `UIColor.white`). For each wrapper member
whose selector selectors.json (from selectors.py) gives a different Swift name,
this writes a member with Swift's name, in an extension of the same protocol,
that calls it, so VLC's sources keep Swift's spelling:

- methods and initializers, with Swift's argument labels, and `= nil` defaults
  for trailing optional closures (completion handlers), as Swift imports them;
- methods without arguments that Swift imports as properties (class properties
  such as `UIColor.white` and `UIApplication.shared`, from iOS 10's headers);
- properties Swift renames;
- classes Swift renames (NS_SWIFT_NAME, such as PlaybackService for
  VLCPlaybackService), as type aliases of the wrappers and their protocols.

usage: swiftnames.py <selectors.json> <generated wrappers.swift> <module> <output.swift> [other sources]...

Type names the module's other sources declare (its hand-written overlays) are
not aliased.
"""

import json
import re
import sys

EXTENSION = re.compile(r"^extension (\w+)Methods( where Self: ObjCWrapper)? \{")
MEMBER = re.compile(r'^\s*(?:@ObjCMethod\("([^"]+)"\) )?public (static func|func|init)(?: (\w+))?\((.*)$')
PROPERTY = re.compile(r'^\s*@ObjCProperty(?:\((.*)\))? public var (\w+): (.+)$')
SEND = re.compile(r'send\("([^"]+)"')
DECLARED_FUNC = re.compile(r"\b(?:func (\w+)|(init))\(")
DECLARED_VAR = re.compile(r"\bvar (\w+)\b")
KEYWORDS = {"associatedtype", "class", "default", "defer", "deinit", "do", "else", "enum", "extension",
            "fallthrough", "for", "func", "guard", "if", "import", "in", "init", "inout", "internal", "is",
            "let", "operator", "private", "protocol", "public", "repeat", "rethrows", "return", "self",
            "static", "struct", "subscript", "super", "switch", "throw", "throws", "try", "typealias", "var",
            "where", "while", "Any", "Self", "Type"}
TITLE = re.compile(r"^(\w+)\((.*)\)$")


def split_top(text, separator=","):
    """Splits at separators outside brackets."""
    parts, depth, current = [], 0, ""
    for index, character in enumerate(text):
        if character in "([<{":
            depth += 1
        elif character in ")]}" or (character == ">" and text[index - 1:index] != "-"):
            depth -= 1
        if character == separator and depth == 0:
            parts.append(current.strip())
            current = ""
        else:
            current += character
    if current.strip():
        parts.append(current.strip())
    return parts


def close_paren(text):
    """The index of the parenthesis closing a list that text begins inside."""
    depth = 1
    for index, character in enumerate(text):
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth == 0:
                return index
    return -1


def parse_member(line):
    match = MEMBER.match(line)
    if not match:
        return None
    selector, kind, name, rest = match.groups()
    end = close_paren(rest)
    if end < 0:
        return None
    parameters = []
    for parameter in split_top(rest[:end]):
        head, _, type_ = parameter.partition(":")
        words = head.split()
        if len(words) != 2:
            return None
        parameters.append((words[0], words[1], type_.strip()))
    tail = rest[end + 1:]
    returns = None
    arrow = re.match(r"\s*->\s*(.+?)\s*(\{.*)?$", tail)
    if arrow:
        returns = arrow.group(1)
    if selector is None:
        sent = SEND.search(tail)
        if not sent:
            return None
        selector = sent.group(1)
    return {"selector": selector, "kind": kind, "name": name or "init", "parameters": parameters, "returns": returns}


def identifier(name):
    return f"`{name}`" if name in KEYWORDS else name


def labels_of(parameters):
    return tuple(label.strip("`") for label, _, _ in parameters)


def signature(name, labels):
    return f"{name}({''.join(label + ':' for label in labels)})"


def is_optional_closure(type_):
    return type_.endswith(")?") and "->" in type_


def main():
    if len(sys.argv) < 5:
        sys.exit(__doc__.strip().splitlines()[-4])
    selectors, source, module, output = sys.argv[1:5]
    others = [path for path in sys.argv[5:] if path != output]
    taken = set()
    for path in others:
        taken.update(re.findall(r"\b(?:struct|class|enum|protocol|typealias|actor) (\w+)", open(path).read()))
    selector_map = json.load(open(selectors))
    containers = selector_map["containers"]
    type_names = selector_map.get("names", {})
    text = open(source).read()
    # Each protocol's declared names: never redeclared
    declared = {}  # protocol -> (funcs, vars)
    current = None
    for line in text.splitlines():
        match = EXTENSION.match(line)
        if match:
            current = declared.setdefault(match.group(1), (set(), set()))
            continue
        if line.startswith("}") or current is None:
            current = None if line.startswith("}") else current
            continue
        member = parse_member(line)
        if member:
            current[0].add(signature(member["name"], labels_of(member["parameters"])))
        current[1].update(DECLARED_VAR.findall(line))

    aliases = {}  # (protocol, wrapper only) -> lines
    current = None
    for line in text.splitlines():
        match = EXTENSION.match(line)
        if match:
            current = (match.group(1), bool(match.group(2)))
            continue
        if line.startswith("}"):
            current = None
            continue
        if current is None:
            continue
        container = containers.get(current[0])
        if container is None:
            continue
        lines = aliases.setdefault(current, [])
        declared_funcs, declared_vars = declared[current[0]]

        property_ = PROPERTY.match(line)
        if property_:
            arguments, name, type_ = property_.groups()
            readonly = arguments is not None and "readonly: true" in arguments
            for title, (getter, _) in container["properties"].items():
                if getter != name or title == name or title in declared_vars or title.startswith("is"):
                    continue
                declared_vars.add(title)
                if readonly:
                    lines.append(f"    public var {identifier(title)}: {type_} {{ {name} }}")
                else:
                    lines.append(f"    public var {identifier(title)}: {type_} {{\n        get {{ {name} }}\n"
                                 f"        nonmutating set {{ {name} = newValue }}\n    }}")
            continue

        member = parse_member(line)
        if member is None:
            continue
        static = member["kind"] == "static func"
        selector = member["selector"]
        parameters = member["parameters"]
        call_labels = labels_of(parameters)

        # A method without arguments that Swift imports as a property
        if not parameters and member["returns"] and member["kind"] != "init":
            for title, (getter, _) in container["properties"].items():
                if getter != selector or title == member["name"] or title in declared_vars:
                    continue
                declared_vars.add(title)
                prefix = "static " if static else ""
                lines.append(f"    public {prefix}var {identifier(title)}: {member['returns']} {{ {member['name']}() }}")

        key = ("class " if static else "")
        titles = [title for title, sel in container["methods"].items()
                  if sel == selector and title.startswith(key) and (static or not title.startswith("class "))]
        for title in titles:
            title = title[len(key):]
            parsed = TITLE.match(title)
            if not parsed:
                continue
            name = parsed.group(1)
            labels = tuple(label for label in parsed.group(2).split(":") if label != "") if parsed.group(2) else ()
            if len(labels) != len(parameters):
                continue
            if (name, labels) == (member["name"], call_labels):
                continue
            if member["kind"] == "init" and name != "init":
                continue
            factory = static and name == "init"  # a class factory method Swift imports as an initializer
            if name in ("subscript", "deinit") or (name == "init" and member["kind"] != "init" and not factory) or (factory and member["returns"] not in ("Self", "Self?")):
                continue
            alias = signature(name, labels)
            if alias in declared_funcs:
                continue
            declared_funcs.add(alias)
            # Swift's defaults: nil for trailing optional closures
            defaults = [""] * len(parameters)
            for index in range(len(parameters) - 1, -1, -1):
                if not is_optional_closure(parameters[index][2]):
                    break
                defaults[index] = " = nil"
            declaration = ", ".join(f"{label} {internal}: {type_}{default}"
                                    for label, (_, internal, type_), default in zip(labels, parameters, defaults))
            arguments = ", ".join(internal if label == "_" else f"{label}: {internal}"
                                  for label, internal, _ in parameters)
            if factory:
                failable = "?" if member["returns"] == "Self?" else ""
                body = (f"guard let made = Self.{member['name']}({arguments}) else {{ return nil }}; self = made"
                        if failable else f"self = Self.{member['name']}({arguments})")
                lines.append(f"    public init{failable}({declaration}) {{ {body} }}")
                continue
            if member["kind"] == "init":
                lines.append(f"    public init({declaration}) {{ self.init({arguments}) }}")
                continue
            returns = f" -> {member['returns']}" if member["returns"] else ""
            prefix = "static " if static else ""
            attribute = "@discardableResult " if member["returns"] else ""
            lines.append(f"    {attribute}public {prefix}func {identifier(name)}({declaration}){returns} "
                         f"{{ {member['name']}({arguments}) }}")

    renamed = []
    for wrapper in re.findall(r"^@ObjC public struct (\w+):", text, re.M):
        if wrapper in type_names and type_names[wrapper] not in taken:
            name = type_names[wrapper]
            renamed.append(f"public typealias {name} = {wrapper}")
            renamed.append(f"public typealias {name}Methods = {wrapper}Methods")

    out = [f"// Swift's names for {module}'s methods and properties, generated by SDK/swiftnames.py",
           "// from the module's wrappers and SDK/selectors.json. Don't edit: regenerate with SDK/generate.sh.", ""]
    imports = re.findall(r"^import \w+$", text, re.M)
    if imports:
        out.extend(imports + [""])
    if renamed:
        out.extend(renamed + [""])
    count = len(renamed) // 2
    for (protocol, wrapper_only) in sorted(aliases):
        lines = aliases[(protocol, wrapper_only)]
        if not lines:
            continue
        count += len(lines)
        out.append(f"extension {protocol}Methods{' where Self: ObjCWrapper' if wrapper_only else ''} {{")
        out.extend(lines)
        out.append("}")
        out.append("")
    with open(output, "w") as handle:
        handle.write("\n".join(out))
    print(f"{module}: {count} Swift names", file=sys.stderr)


if __name__ == "__main__":
    main()
