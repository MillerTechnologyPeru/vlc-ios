#!/usr/bin/env python3
"""Writes the Objective-C selectors of UIKit's, Foundation's and QuartzCore's
Swift names, and those of other Objective-C modules (MobileVLCKit,
VLCMediaLibraryKit, the app's headers), for port.py and swiftnames.py.

Swift renames Objective-C methods (`tableView(_:cellForRowAt:)` is
`tableView:cellForRowAtIndexPath:`), and an @ObjCImplementation override or
protocol method needs the real selector. The symbol graphs of the current
iOS SDK have both: each imported member's title is its Swift name, and its
precise identifier, a Clang USR such as
`c:objc(pl)UITableViewDataSource(im)tableView:cellForRowAtIndexPath:`, has
its container and selector.

usage: selectors.py <output.json> [-F <frameworks folder>]... [module]...

The output maps each class and protocol to its methods' and initializers'
Swift names and selectors, and its properties' Swift names, getters and
setters, with each class's superclass and protocols, the protocols' names, and
the Swift names of classes Swift renames (NS_SWIFT_NAME).
"""

import glob
import json
import os
import re
import subprocess
import sys
import tempfile

MODULES = ["UIKit", "Foundation", "QuartzCore"]
USR = re.compile(r"^c:objc\((cs|pl)\)([A-Za-z0-9_]+)\((im|cm|py|cpy)\)(.+)$")
CONTAINER = re.compile(r"^c:objc\((cs|pl)\)([A-Za-z0-9_]+)$")


def extract(directory, modules, framework_paths):
    sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
    flags = [flag for path in framework_paths for flag in ("-F", path)]
    for module in modules:
        subprocess.check_call(["xcrun", "swift-symbolgraph-extract", "-module-name", module,
                               "-target", "arm64-apple-ios17.0", "-sdk", sdk, *flags, "-output-dir", directory,
                               "-minimum-access-level", "public"], stderr=subprocess.DEVNULL)


def main():
    arguments = sys.argv[1:]
    if not arguments or arguments[0].startswith("-"):
        sys.exit(__doc__.strip().splitlines()[-6])
    output, modules, framework_paths = arguments[0], list(MODULES), []
    rest = iter(arguments[1:])
    for argument in rest:
        if argument == "-F":
            framework_paths.append(next(rest))
        else:
            modules.append(argument)
    names = {}  # Objective-C name -> Swift name, where Swift renames it
    containers = {}
    superclasses = {}
    conformances = {}  # class or protocol -> protocols it adopts or refines
    protocols = set()
    with tempfile.TemporaryDirectory() as directory:
        extract(directory, modules, framework_paths)
        for path in sorted(glob.glob(os.path.join(directory, "*.symbols.json"))):
            graph = json.load(open(path))
            for symbol in graph["symbols"]:
                precise = symbol["identifier"]["precise"]
                container = CONTAINER.match(precise)
                if container:
                    if container.group(1) == "pl":
                        protocols.add(container.group(2))
                    title = symbol["names"]["title"]
                    if container.group(1) == "cs" and title != container.group(2) and "." not in title:
                        names[container.group(2)] = title
                    continue
                match = USR.match(precise)
                if not match:
                    continue
                kind, owner, member, name = match.groups()
                if kind == "pl":
                    protocols.add(owner)
                title = symbol["names"]["title"]
                entry = containers.setdefault(owner, {"methods": {}, "properties": {}})
                if member in ("im", "cm"):
                    key = ("class " if member == "cm" else "") + title
                    entry["methods"].setdefault(key, name)
                else:
                    getter = title if title != name and title.startswith("is") else name
                    entry["properties"].setdefault(title, [getter, f"set{name[:1].upper()}{name[1:]}:"])
            for relationship in graph["relationships"]:
                if relationship["kind"] not in ("inheritsFrom", "conformsTo"):
                    continue
                source = CONTAINER.match(relationship["source"])
                target = CONTAINER.match(relationship["target"])
                if not (source and target):
                    continue
                if relationship["kind"] == "inheritsFrom":
                    superclasses[source.group(2)] = target.group(2)
                else:
                    conformances.setdefault(source.group(2), set()).add(target.group(2))
    result = {"containers": dict(sorted(containers.items())), "superclasses": dict(sorted(superclasses.items())),
              "conformances": {name: sorted(adopted) for name, adopted in sorted(conformances.items())},
              "protocols": sorted(protocols), "names": dict(sorted(names.items()))}
    with open(output, "w") as handle:
        json.dump(result, handle, indent=0, sort_keys=True)
        handle.write("\n")
    methods = sum(len(c["methods"]) for c in containers.values())
    print(f"{len(containers)} classes and protocols, {methods} methods, {len(protocols)} protocols", file=sys.stderr)


if __name__ == "__main__":
    main()
