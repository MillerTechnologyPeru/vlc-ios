#!/usr/bin/env python3
"""Rewrites VLC's Swift classes for Embedded Swift's Objective-C interop.

Embedded Swift has no @objc, no #selector and no Objective-C superclasses:
UIKit's classes are wrapper structs (UIView) with protocols that carry their
members (UIViewMethods), and Swift classes implement Objective-C classes
with ObjCInterop's @ObjCImplementation. This turns

    class Cell: UITableViewCell, UITableViewDelegate {
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layoutSubviews() { super.layoutSubviews() }
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { … }
        @objc func tapped(_ sender: UIButton) { … }
    }

into

    @ObjCImplementation(protocols: ["UITableViewDelegate"])
    class Cell: UITableViewCellMethods {
        init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            objcInit("initWithStyle:reuseIdentifier:", style, reuseIdentifier)
        }
        @ObjCMethod("layoutSubviews") func layoutSubviews() { callSuper("layoutSubviews") }
        @ObjCMethod("tableView:didSelectRowAtIndexPath:") func tableView(…) { … }
        @ObjCMethod func tapped(_ sender: UIButton) { … }
    }

- A class whose superclass is a wrapped class, or a class this converts,
  gets @ObjCImplementation. Generic classes, and those whose superclass is
  one of the app's own Objective-C classes, are left (and listed).
- Objective-C protocols move from the inheritance clause to `protocols:`.
- Overrides, and methods that implement an adopted protocol's requirements,
  get @ObjCMethod with the selector from selectors.json (selectors.py).
  An override of a method that a converted Swift superclass declares stays
  an ordinary Swift override.
- Extensions of converted classes get @ObjCExtension, listed in the class's
  `extensions:`, and their protocols join the class's.
- `super.m(…)` calls to Objective-C methods become `callSuper("m:", …)`, and
  `super.init(…)` in a root class becomes `objcInit("init…", …)`.
  `required init?(coder:)` initializers that only fail are removed.
- @objc becomes @ObjCMethod on methods and goes elsewhere, and
  `#selector(m(_:))` becomes `ObjC.selector("m:")`, with the selector the
  method exports.

usage: port.py [--dry-run] <repository root>
"""

import collections
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MODIFIERS = r"(?:(?:public|private|fileprivate|internal|open|final|private\(set\)|public\(set\)|fileprivate\(set\)|internal\(set\))\s+)*"


# MARK: - Scanning

def mask(text):
    """The text with comments and string literals blanked (same length), so
    braces and keywords in them don't count."""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = " "
            i = j
        elif text.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if text.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif text.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            for k in range(i, j):
                if out[k] != "\n":
                    out[k] = " "
            i = j
        elif c == '"' or (c == "#" and text.startswith('#"', i)):
            hashes = 0
            while text[i + hashes] == "#":
                hashes += 1
            start = i
            j = i + hashes
            multiline = text.startswith('"""', j)
            quote = '"""' if multiline else '"'
            closing = quote + "#" * hashes
            j += len(quote)
            depth = 0
            while j < n:
                if text[j] == "\\" and hashes == 0:
                    if text.startswith("\\(", j):
                        depth += 1
                        j += 2
                        continue
                    j += 2
                    continue
                if depth:
                    if text[j] == "(":
                        depth += 1
                    elif text[j] == ")":
                        depth -= 1
                    j += 1
                    continue
                if text.startswith(closing, j):
                    j += len(closing)
                    break
                if text[j] == "\n" and not multiline:
                    break
                j += 1
            for k in range(start + 1, max(start + 1, j - 1)):
                if out[k] != "\n":
                    out[k] = " "
            i = j
        else:
            i += 1
    return "".join(out)


def matching(masked, open_index, opening="{", closing="}"):
    """The index of the bracket that closes the one at open_index."""
    depth = 0
    for i in range(open_index, len(masked)):
        if masked[i] == opening:
            depth += 1
        elif masked[i] == closing:
            depth -= 1
            if depth == 0:
                return i
    return len(masked) - 1


def split_top(text, separator=","):
    """Splits at separators outside brackets."""
    parts, depth, current = [], 0, []
    for c in text:
        if c in "([{<":
            depth += 1
        elif c in ")]}>":
            depth -= 1
        if c == separator and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(c)
    if "".join(current).strip():
        parts.append("".join(current))
    return parts


def labels_of(parameters):
    """The argument labels of a parameter clause's text."""
    labels = []
    for parameter in split_top(parameters):
        names = parameter.split(":")[0].split()
        names = [name for name in names if name not in ("inout", "borrowing", "consuming", "isolated")]
        labels.append(names[0] if names else "_")
    return labels


def title(name, labels):
    return f"{name}({''.join(f'{label}:' for label in labels)})"


def macro_selector(name, labels):
    """The selector @ObjCMethod derives from a method's name and labels."""
    selector = name
    for index, label in enumerate(labels):
        if index == 0:
            selector += ("" if label == "_" else label[:1].upper() + label[1:]) + ":"
        else:
            selector += ("" if label == "_" else label) + ":"
    return selector


def call_labels(arguments):
    """The labels and values of a call's arguments."""
    labels, values = [], []
    for argument in split_top(arguments):
        match = re.match(r"\s*([A-Za-z_]\w*)\s*:(?!:)\s*(.*)$", argument, re.S)
        if match and not argument.strip().startswith("{"):
            labels.append(match.group(1))
            values.append(match.group(2).strip())
        else:
            labels.append("_")
            values.append(argument.strip())
    return labels, values


# MARK: - The model

class Declaration:
    """A class or an extension, and its methods."""

    def __init__(self, path, kind, name, start, body_open, body_close, inherits, header_span):
        self.path, self.kind, self.name = path, kind, name
        self.start, self.body_open, self.body_close = start, body_open, body_close
        self.inherits = inherits            # [type names]
        self.header_span = header_span      # (start, end) of the inheritance clause text, or None
        self.methods = []                   # Method
        self.objc_name = None


class Method:
    def __init__(self, decl_start, func_index, name, labels, explicit, is_override, is_objc, kind):
        self.decl_start, self.func_index = decl_start, func_index
        self.name, self.labels = name, labels
        self.explicit = explicit            # @objc(sel:) selector
        self.is_override, self.is_objc, self.kind = is_override, is_objc, kind

    @property
    def title(self):
        return title(self.name, self.labels)


CLASS = re.compile(
    r"(?m)^(?P<indent>[ \t]*)(?P<attrs>(?:@\w+(?:\([^()\n]*\))?\s+)*)" + MODIFIERS +
    r"(?P<kind>class|extension)\s+(?P<name>[A-Za-z_][\w.]*)(?P<generic><[^>{\n]*>)?\s*"
    r"(?::\s*(?P<inherits>[^{\n]+?))?\s*(?:where\s[^{]*)?\{")
FUNC = re.compile(
    r"(?<![\w.])(?P<attrs>(?:@\w+(?:\([^()\n]*\))?\s+)*)(?P<mods>(?:(?:public|private|fileprivate|internal|open|final|"
    r"override|static|class|required|convenience|dynamic|nonisolated|mutating|optional|@\w+)\s+)*)"
    r"(?P<kind>func\s+(?P<name>[A-Za-z_]\w*)|init[?!]?)\s*(?P<generic><[^>]*>)?\s*\(")


def parse(path, text):
    masked = mask(text)
    declarations = []
    for match in CLASS.finditer(masked):
        name = match.group("name")
        if match.group("kind") == "class" and name in ("var", "func", "let"):
            continue
        body_open = match.end() - 1
        body_close = matching(masked, body_open)
        inherits = [part.strip() for part in split_top(match.group("inherits") or "")]
        span = (match.start("inherits"), match.end("inherits")) if match.group("inherits") else None
        start = match.start() + len(match.group("indent"))
        decl = Declaration(path, match.group("kind"), name, start, body_open, body_close, inherits, span)
        decl.generic = bool(match.group("generic"))
        attrs = match.group("attrs") or ""
        objc = re.search(r"@objc\(([^)]*)\)", attrs)
        decl.objc_name = objc.group(1) if objc else None
        declarations.append(decl)
    # Methods at the top level of each declaration's body
    for decl in declarations:
        inner = [d for d in declarations if decl.body_open < d.start < decl.body_close]
        position = decl.body_open + 1
        for match in FUNC.finditer(masked, decl.body_open + 1, decl.body_close):
            if any(d.start <= match.start() <= d.body_close for d in inner):
                continue
            if depth_at(masked, decl.body_open, match.start()) != 1:
                continue
            paren = match.end() - 1
            close = matching(masked, paren, "(", ")")
            parameters = text[paren + 1:close]
            attrs = match.group("attrs") + match.group("mods")
            explicit = re.search(r"@objc\(([^)]*)\)", attrs)
            kind = "init" if match.group("kind").startswith("init") else "func"
            name = match.group("name") or "init"
            method = Method(match.start(), match.start("kind"), name, labels_of(parameters),
                            explicit.group(1) if explicit else None,
                            re.search(r"\boverride\b", match.group("mods")) is not None,
                            "@objc" in attrs, kind)
            method.static = re.search(r"\b(static|class)\s", match.group("mods")) is not None
            method.convenience = re.search(r"\bconvenience\s", match.group("mods")) is not None
            method.paren, method.paren_close = paren, close
            brace = masked.find("{", close)
            method.body = (brace, matching(masked, brace)) if brace >= 0 else None
            signature = text[close + 1:brace] if brace >= 0 else ""
            returns = re.search(r"->\s*(.+?)\s*(?:\bwhere\b.*)?$", signature.strip(), re.S)
            method.returns = returns.group(1).strip() if returns else None
            decl.methods.append(method)
            position = close
    return declarations


def depth_at(masked, start, index):
    depth = 0
    for c in masked[start:index]:
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
    return depth


# MARK: - Porting

class Port:
    def __init__(self, root):
        self.root = root
        data = json.load(open(os.path.join(HERE, "selectors.json")))
        self.containers = data["containers"]
        self.superclasses = data["superclasses"]
        self.conformances = data["conformances"]
        self.objc_protocols = set(data["protocols"]) | self.framework_protocols()
        self.wrapped = self.wrapped_classes()
        self.report = collections.Counter()
        self.notes = collections.defaultdict(list)

    def framework_protocols(self):
        names = set()
        for header in glob.glob(os.path.join(self.root, "..", "VLCKit-iOS6-3", "build", "iOS6", "*.framework",
                                             "Headers", "*.h")) + \
                glob.glob(os.path.join(self.root, "..", "VLCMediaLibraryKit-iOS6", "build", "iOS6", "*.framework",
                                       "Headers", "*.h")):
            names |= set(re.findall(r"@protocol\s+(\w+)\s*[<\n]", open(header, errors="replace").read()))
        return names

    def wrapped_classes(self):
        names = set()
        sources = glob.glob(os.path.join(self.root, "..", "Swift-iOS6", "Frameworks", "*", "Sources", "*.swift")) + \
            glob.glob(os.path.join(HERE, "*", "*.swift"))
        for path in sources:
            names |= set(re.findall(r"public protocol (\w+)Methods:", open(path).read()))
        return names

    def sources(self):
        paths = []
        for directory, _, files in os.walk(os.path.join(self.root, "Sources")):
            if "/Sources/App/iOS6" in directory or "watchOS" in directory:
                continue
            paths += [os.path.join(directory, name) for name in files if name.endswith(".swift")]
        return sorted(paths)

    # The Objective-C side of a class: its wrapped ancestors and protocols.
    def objc_chain(self, name):
        chain = []
        while name:
            chain.append(name)
            name = self.superclasses.get(name)
        return chain

    def protocol_closure(self, names):
        seen, queue = [], list(names)
        while queue:
            name = queue.pop(0)
            if name in seen:
                continue
            seen.append(name)
            queue += self.conformances.get(name, [])
        return seen

    def lookup(self, containers, key):
        for container in containers:
            selector = self.containers.get(container, {}).get("methods", {}).get(key)
            if selector:
                return selector
        return None

    def analyze(self):
        self.texts = {path: open(path).read() for path in self.sources()}
        self.decls = {path: parse(path, text) for path, text in self.texts.items()}
        classes = {}
        swift_protocols = set()
        for path, decls in self.decls.items():
            for decl in decls:
                if decl.kind == "class":
                    classes.setdefault(decl.name, decl)
            swift_protocols |= set(re.findall(r"(?m)^\s*(?:@\w+(?:\([^)]*\))?\s+)*" + MODIFIERS + r"protocol\s+(\w+)",
                                              mask(self.texts[path])))
        self.classes = classes
        self.swift_protocols = swift_protocols
        # Converted classes: the wrapped class's subclasses, then theirs.
        converted = {}
        changed = True
        while changed:
            changed = False
            for name, decl in classes.items():
                if name in converted or not decl.inherits:
                    continue
                base = decl.inherits[0].split(".")[-1]
                if base in self.wrapped and base not in classes:
                    converted[name] = ("wrapper", base)
                    changed = True
                elif base in converted:
                    converted[name] = ("swift", base)
                    changed = True
        for name, decl in classes.items():
            if name in converted and decl.generic:
                del converted[name]
                self.notes["generic classes left"].append(name)
        for name, decl in classes.items():
            if name not in converted and decl.inherits:
                base = decl.inherits[0].split(".")[-1]
                if base not in self.wrapped and base not in classes and base not in swift_protocols and \
                        base not in self.objc_protocols and base[:1].isupper() and base not in ("Equatable", "Hashable",
                                                                                                "Codable", "Error"):
                    self.notes["superclass without a wrapper"].append(f"{name}: {base}")
        self.converted = converted
        # Each converted class's extensions, protocols and members
        self.extensions = collections.defaultdict(list)
        for decls in self.decls.values():
            for decl in decls:
                if decl.kind == "extension" and decl.name in converted:
                    self.extensions[decl.name].append(decl)
        self.protocols = {}
        for name in converted:
            adopted = []
            for decl in [classes[name]] + self.extensions[name]:
                for inherited in decl.inherits[(1 if decl.kind == "class" else 0):]:
                    if self.is_objc_protocol(inherited):
                        adopted.append(inherited)
            self.protocols[name] = list(dict.fromkeys(adopted))

    def is_objc_protocol(self, name):
        return name in self.objc_protocols and name not in self.swift_protocols

    def wrapper_root(self, name):
        while self.converted[name][0] == "swift":
            name = self.converted[name][1]
        return self.converted[name][1]

    def swift_ancestors(self, name):
        """The converted Swift superclasses, nearest first."""
        result = []
        while self.converted[name][0] == "swift":
            name = self.converted[name][1]
            result.append(name)
        return result

    def declares(self, class_name, method_title, static=False):
        """Whether a converted class, or its extensions, declares a method."""
        for decl in [self.classes[class_name]] + self.extensions[class_name]:
            for method in decl.methods:
                if method.title == method_title and method.static == static:
                    return True
        return False

    def objc_containers(self, name):
        """Where the Objective-C selectors of a converted class's methods come from."""
        protocols = []
        for ancestor in [name] + self.swift_ancestors(name):
            protocols += self.protocols.get(ancestor, [])
        chain = self.objc_chain(self.wrapper_root(name))
        return chain + self.protocol_closure(protocols + [p for c in chain for p in self.conformances.get(c, [])])

    def method_selector(self, class_name, method):
        """The selector a method of a converted class exports, or None if it doesn't."""
        if method.explicit:
            return method.explicit
        key = ("class " if method.static else "") + method.title
        if method.kind == "init":
            return None
        selector = self.lookup(self.objc_containers(class_name), key)
        if selector:
            return selector
        if method.is_objc:
            return macro_selector(method.name, method.labels)
        return None

    # MARK: Rewriting

    def run(self, dry_run):
        self.analyze()
        changed = 0
        for path, text in self.texts.items():
            new = self.rewrite(path, text)
            if new != text:
                changed += 1
                if not dry_run:
                    with open(path, "w") as handle:
                        handle.write(new)
        self.report["files changed"] = changed
        self.report["classes converted"] = len(self.converted)
        for key, value in sorted(self.report.items()):
            print(f"{value:5d}  {key}")
        for key, values in sorted(self.notes.items()):
            print(f"{key} ({len(values)}): " + ", ".join(sorted(set(values))[:40]))

    def rewrite(self, path, text):
        edits = []  # (start, end, replacement)
        masked = mask(text)
        decls = self.decls[path]
        for decl in decls:
            name = decl.name
            if name not in self.converted:
                continue
            is_class = decl.kind == "class"
            root = self.converted[name][0] == "wrapper"
            # The header
            if decl.header_span:
                kept = []
                for index, inherited in enumerate(decl.inherits):
                    if is_class and index == 0:
                        kept.append(f"{self.converted[name][1]}Methods" if root else inherited)
                    elif not self.is_objc_protocol(inherited):
                        kept.append(inherited)
                clause = ", ".join(kept)
                start, end = decl.header_span
                if clause:
                    edits.append((start, end, clause))
                else:
                    colon = masked.rfind(":", 0, start)
                    edits.append((colon, end, ""))
            tags = []
            if is_class:
                for extension in self.extensions[name]:
                    if self.exported(name, extension):
                        tags.append(self.tag(name, extension))
                arguments = []
                if decl.objc_name:
                    arguments.append(f'"{decl.objc_name}"')
                if self.protocols[name]:
                    arguments.append("protocols: [" + ", ".join(f'"{p}"' for p in self.protocols[name]) + "]")
                if tags:
                    arguments.append("extensions: [" + ", ".join(f'"{t}"' for t in tags) + "]")
                macro = "@ObjCImplementation" + (f"({', '.join(arguments)})" if arguments else "")
                edits.append((decl.start, decl.start, macro + "\n" + " " * self.indent(text, decl.start)))
                self.report["class headers"] += 1
            elif self.exported(name, decl):
                edits.append((decl.start, decl.start, f'@ObjCExtension("{self.tag(name, decl)}")\n'
                              + " " * self.indent(text, decl.start)))
                self.report["extensions"] += 1
            # @objc(Name) and @objcMembers on the class
            header = masked[decl.start:decl.body_open]
            for attr in re.finditer(r"@objc(?:Members|\([^)]*\))?\s+", header):
                edits.append((decl.start + attr.start(), decl.start + attr.end(), ""))
            # Members
            for method in decl.methods:
                edits += self.rewrite_method(text, masked, decl, method, root)
            if is_class and root and not any(m.kind == "init" for m in decl.methods):
                # The implicit init(), with the object
                indent = " " * (self.indent(text, decl.start) + 4)
                edits.append((decl.body_open + 1, decl.body_open + 1, f"\n{indent}init() {{ objcInit() }}\n"))
                self.report["init() added"] += 1
        # @objc elsewhere, and #selector, everywhere in the file
        edits += self.rewrite_objc(text, masked, edits)
        edits += self.rewrite_selectors(path, text, masked, edits)
        return apply(text, edits)

    def indent(self, text, index):
        line = text.rfind("\n", 0, index) + 1
        return len(text[line:index]) - len(text[line:index].lstrip())

    def exported(self, name, extension):
        return any(self.method_selector(name, method) for method in extension.methods if method.kind == "func")

    def tag(self, name, extension):
        if not hasattr(self, "tags"):
            self.tags = {}
        key = (extension.path, extension.start)
        if key not in self.tags:
            base = "".join(part for part in re.findall(r"\w+", extension.inherits[0] if extension.inherits else "")) \
                or "Extension"
            used = {tag for (path, start), tag in self.tags.items() if self.tag_owner.get((path, start)) == name}
            tag, number = base, 2
            while tag in used:
                tag, number = f"{base}{number}", number + 1
            self.tags[key] = tag
            self.tag_owner = getattr(self, "tag_owner", {})
            self.tag_owner[key] = name
        return self.tags[key]

    def rewrite_method(self, text, masked, decl, method, root):
        edits = []
        name = decl.name
        ancestors = self.swift_ancestors(name)
        inherited = any(self.declares(ancestor, method.title, method.static) for ancestor in ancestors)
        mods_region = masked[method.decl_start:method.func_index]
        if method.kind == "init":
            if method.labels == ["coder"] and method.body and self.only_fails(masked, method.body):
                line_start = text.rfind("\n", 0, method.decl_start) + 1
                end = method.body[1] + 1
                if text[end:end + 1] == "\n":
                    end += 1
                if not text[line_start:method.decl_start].strip():
                    edits.append((line_start, end, ""))
                    self.report["init(coder:) removed"] += 1
                    return edits
            if root:
                for keyword in re.finditer(r"\b(override|required)\s+", mods_region):
                    edits.append((method.decl_start + keyword.start(), method.decl_start + keyword.end(), ""))
            if method.body:
                edits += self.rewrite_super_init(text, masked, name, method, root)
                edits += self.rewrite_super_calls(text, masked, name, method)
                inside = masked[method.body[0]:method.body[1]]
                if root and not method.convenience and decl.kind == "class" and \
                        not re.search(r"\b(super|self)\.init\b", inside):
                    # Swift's implicit super.init(): make the object
                    close = method.body[1]
                    indent = self.indent(text, close)
                    edits.append((close, close, " " * 4 + "objcInit()\n" + " " * indent
                                  if not text[text.rfind("\n", 0, close) + 1:close].strip() else "; objcInit() "))
                    self.report["implicit super.init → objcInit"] += 1
            return edits
        selector = None if inherited else self.method_selector(name, method)
        if selector:
            attr = f'@ObjCMethod("{selector}") ' if (method.explicit or not method.is_objc or
                                                      selector != macro_selector(method.name, method.labels)) \
                else "@ObjCMethod "
            objc = re.search(r"@objc(?:\([^)]*\))?\s+", mods_region)
            if objc:
                edits.append((method.decl_start + objc.start(), method.decl_start + objc.end(), attr))
            else:
                edits.append((method.decl_start, method.decl_start, attr))
            self.report["methods exported"] += 1
        if method.is_override and not inherited:
            keyword = re.search(r"\boverride\s+", mods_region)
            if keyword:
                edits.append((method.decl_start + keyword.start(), method.decl_start + keyword.end(), ""))
        if method.body:
            edits += self.rewrite_super_calls(text, masked, name, method)
        return edits

    def only_fails(self, masked, body):
        inside = masked[body[0] + 1:body[1]].strip()
        return inside.startswith("fatalError(") or inside == "return nil" or inside.startswith("preconditionFailure(")

    def rewrite_super_init(self, text, masked, name, method, root):
        edits = []
        if not root:
            return edits
        for match in re.finditer(r"\bsuper\.init\s*\(", masked[method.body[0]:method.body[1]]):
            start = method.body[0] + match.start()
            paren = method.body[0] + match.end() - 1
            close = matching(masked, paren, "(", ")")
            labels, values = call_labels(text[paren + 1:close])
            key = title("init", labels)
            selector = "init" if not labels else self.lookup(self.objc_containers(name), key)
            if not selector:
                self.notes["super.init without a selector"].append(f"{name}.{key}")
                continue
            arguments = "".join(f", {value}" for value in values)
            edits.append((start, close + 1, f'objcInit("{selector}"{arguments})'))
            self.report["super.init → objcInit"] += 1
        return edits

    def rewrite_super_calls(self, text, masked, name, method):
        edits = []
        ancestors = self.swift_ancestors(name)
        for match in re.finditer(r"\bsuper\.([A-Za-z_]\w*)\s*(\()?", masked[method.body[0]:method.body[1]]):
            member = match.group(1)
            if member == "init":
                continue
            start = method.body[0] + match.start()
            if match.group(2):
                paren = method.body[0] + match.end() - 1
                close = matching(masked, paren, "(", ")")
                labels, values = call_labels(text[paren + 1:close])
                key = title(member, labels)
                if any(self.declares(ancestor, key) for ancestor in ancestors):
                    continue
                selector = self.lookup(self.objc_containers(name), key)
                if not selector:
                    self.notes["super call without a selector"].append(f"{name}: {key}")
                    continue
                arguments = "".join(f", {value}" for value in values)
                call = f'callSuper("{selector}"{arguments})'
                if key == method.title and method.returns:
                    # The method's own super implementation: its result type
                    call = f"({call} as {method.returns})"
                edits.append((start, close + 1, call))
                self.report["super calls → callSuper"] += 1
            else:
                # super.property: read it through the wrapper's members
                edits.append((start, start + len("super"), "self"))
                self.report["super properties → self"] += 1
        return edits

    def rewrite_objc(self, text, masked, existing):
        """@objc on methods outside converted classes becomes @ObjCMethod (a no-op
        there), and @objc, @objcMembers and dynamic go from everything else."""
        taken = [(start, end) for start, end, _ in existing]
        edits = []
        for match in re.finditer(r"@objc(Members)?(\(([^)]*)\))?\s+", masked):
            if any(start <= match.start() < max(end, start + 1) for start, end in taken):
                continue
            after = masked[match.end():match.end() + 200]
            following = re.match(r"((?:@\w+(?:\([^)]*\))?\s+|(?:public|private|fileprivate|internal|open|final|override|"
                                 r"static|class|dynamic|optional|nonisolated)\s+)*)(\w+)", after)
            keyword = following.group(2) if following else ""
            if keyword == "func" and not match.group(1) and self.has_body(masked, match.end()):
                name = match.group(3)
                edits.append((match.start(), match.end(), f'@ObjCMethod("{name}") ' if name else "@ObjCMethod "))
            else:
                edits.append((match.start(), match.end(), ""))
            self.report["@objc rewritten"] += 1
        for match in re.finditer(r"\bdynamic\s+(?=(?:(?:public|private|fileprivate|internal|open|final|override)\s+)*"
                                 r"(?:var|func)\b)", masked):
            if not any(start <= match.start() < max(end, start + 1) for start, end in taken):
                edits.append((match.start(), match.end(), ""))
        return edits

    def has_body(self, masked, index):
        """Whether the func declared after index has a body (a protocol requirement has none)."""
        paren = masked.find("(", index)
        if paren < 0:
            return False
        close = matching(masked, paren, "(", ")")
        rest = re.match(r"[^{}\n]*(?:\n[ \t]*(?:->|where|throws|async)[^{}\n]*)*", masked[close + 1:])
        following = masked[close + 1 + rest.end():close + 2 + rest.end()]
        return following == "{" or masked[close + 1:].lstrip().startswith("{")

    def rewrite_selectors(self, path, text, masked, existing):
        edits = []
        for match in re.finditer(r"#selector\s*\(", masked):
            paren = match.end() - 1
            close = matching(masked, paren, "(", ")")
            expression = re.sub(r"^\s*(getter|setter)\s*:\s*", "", text[paren + 1:close]).strip()
            selector = self.resolve_selector(path, match.start(), expression)
            if selector:
                edits.append((match.start(), close + 1, f'ObjC.selector("{selector}")'))
                self.report["#selector resolved"] += 1
            else:
                self.notes["#selector unresolved"].append(expression)
        return edits

    def resolve_selector(self, path, index, expression):
        match = re.match(r"^(?:(?P<type>[A-Z][\w.]*)\.|self\.)?(?P<name>[A-Za-z_]\w*)(?:\((?P<labels>[\w:]*)\))?$",
                         expression.replace(" ", ""))
        if not match:
            return None
        name = match.group("name")
        labels = [label for label in (match.group("labels") or "").split(":")[:-1]] if match.group("labels") is not None \
            else None
        owner = match.group("type")
        if owner:
            owner = owner.split(".")[-1]
        else:
            owner = self.enclosing(path, index)
        candidates = []
        if owner in self.classes:
            names = [owner] + (self.swift_ancestors(owner) if owner in self.converted else [])
            for class_name in names:
                for decl in [self.classes[class_name]] + self.extensions.get(class_name, []) + \
                        [d for ds in self.decls.values() for d in ds if d.kind == "extension" and d.name == class_name
                         and class_name not in self.converted]:
                    for method in decl.methods:
                        if method.name == name and method.kind == "func" and (labels is None or method.labels == labels):
                            candidates.append((class_name, method))
            if candidates:
                class_name, method = candidates[0]
                if class_name in self.converted:
                    selector = self.method_selector(class_name, method)
                    if selector:
                        return selector
                return method.explicit or macro_selector(method.name, method.labels)
            if owner in self.converted:
                containers = self.objc_containers(owner)
            else:
                containers = []
        else:
            containers = self.protocol_closure(self.objc_chain(owner)) if owner else []
        for container in containers:
            methods = self.containers.get(container, {}).get("methods", {})
            if labels is not None:
                selector = methods.get(title(name, labels))
                if selector:
                    return selector
            else:
                found = [selector for key, selector in methods.items() if key.split("(")[0] == name]
                if len(set(found)) == 1:
                    return found[0]
        return None

    def enclosing(self, path, index):
        best = None
        for decl in self.decls[path]:
            if decl.body_open < index < decl.body_close and (best is None or decl.start > best.start):
                best = decl
        return best.name if best else None


def apply(text, edits):
    # Insertions at the same place keep their order; overlapping edits keep the first.
    edits = sorted(enumerate(edits), key=lambda item: (item[1][0], item[0]))
    out, position = [], 0
    for _, (start, end, replacement) in edits:
        if start < position:
            continue
        out.append(text[position:start])
        out.append(replacement)
        position = end
    out.append(text[position:])
    return "".join(out)


def main():
    arguments = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(arguments) != 1:
        sys.exit(__doc__.strip().splitlines()[-1])
    Port(os.path.abspath(arguments[0])).run("--dry-run" in sys.argv)


if __name__ == "__main__":
    main()
