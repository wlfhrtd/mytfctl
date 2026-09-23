#!/usr/bin/env python3

from __future__ import annotations

import ipaddress
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


DEFAULT_MEMORY = 2048
DEFAULT_VCPU = 2
DEFAULT_VM_PREFIX = "lab"
DEFAULT_VM_SUFFIX = "ubuntu"
DEFAULT_BOOTSTRAP_PASSWORD = "ubuntu"

HOSTNAME_RE = re.compile(
    r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$"
)

VM_PART_RE = re.compile(
    r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$"
)


@dataclass(frozen=True)
class Host:
    name: str
    ip: str
    memory: int
    vcpu: int


def die(message: str) -> None:
    print(f"\nERROR: {message}", file=sys.stderr)
    sys.exit(1)


def prompt(
    message: str,
    default: str | None = None,
) -> str:
    if default is not None:
        value = input(f"{message} [{default}]: ").strip()
        return value if value else default

    return input(f"{message}: ").strip()


def validate_hostname(value: str) -> str:
    if not value:
        raise ValueError("hostname cannot be empty")

    if len(value) > 63:
        raise ValueError("hostname must be no longer than 63 characters")

    if not HOSTNAME_RE.fullmatch(value):
        raise ValueError(
            "hostname must contain only lowercase letters, digits and '-' "
            "and must not start or end with '-'"
        )

    return value


def validate_vm_part(value: str, field_name: str) -> str:
    if not value:
        raise ValueError(f"{field_name} cannot be empty")

    if len(value) > 40:
        raise ValueError(f"{field_name} is too long")

    if not VM_PART_RE.fullmatch(value):
        raise ValueError(
            f"{field_name} must contain only lowercase letters, "
            "digits and '-' and must not start or end with '-'"
        )

    return value


def validate_ip(value: str) -> str:
    try:
        address = ipaddress.ip_address(value)
    except ValueError:
        raise ValueError("invalid IP address")

    if address.version != 4:
        raise ValueError("only IPv4 addresses are supported")

    if address.is_loopback:
        raise ValueError("loopback addresses are not allowed")

    if address.is_link_local:
        raise ValueError("link-local addresses are not allowed")

    if address.is_multicast:
        raise ValueError("multicast addresses are not allowed")

    if address.is_unspecified:
        raise ValueError("unspecified address 0.0.0.0 is not allowed")

    return str(address)


def prompt_validated(
    message: str,
    validator,
    default: str | None = None,
) -> str:
    while True:
        try:
            value = prompt(message, default)
            return validator(value)
        except ValueError as exc:
            print(f"  Invalid value: {exc}")


def prompt_int(
    message: str,
    default: int,
    minimum: int,
    maximum: int,
) -> int:
    while True:
        value = prompt(message, str(default))

        try:
            number = int(value)
        except ValueError:
            print("  Invalid value: enter an integer.")
            continue

        if number < minimum or number > maximum:
            print(
                f"  Invalid value: must be between "
                f"{minimum} and {maximum}."
            )
            continue

        return number


def ask_vm_naming() -> tuple[str, str]:
    print("\nVM naming")
    print("The resulting VM name will be:")
    print("  <prefix>-<hostname>-<suffix>\n")

    prefix = prompt_validated(
        "VM name prefix",
        lambda value: validate_vm_part(value, "VM name prefix"),
        DEFAULT_VM_PREFIX,
    )

    suffix = prompt_validated(
        "VM name suffix",
        lambda value: validate_vm_part(value, "VM name suffix"),
        DEFAULT_VM_SUFFIX,
    )

    return prefix, suffix


def ask_host(index: int, existing_names: set[str], existing_ips: set[str]) -> Host | None:
    print(f"\nHost #{index}")
    print("Press Enter on hostname to finish adding hosts.")

    while True:
        raw_name = input("Hostname: ").strip()

        if not raw_name:
            return None

        try:
            name = validate_hostname(raw_name)
        except ValueError as exc:
            print(f"  Invalid hostname: {exc}")
            continue

        if name in existing_names:
            print(f"  Hostname '{name}' is already used.")
            continue

        break

    ip = prompt_validated(
        "IPv4 address",
        validate_ip,
    )

    if ip in existing_ips:
        print(f"  IP address '{ip}' is already used.")
        print("  Each host must have a unique IP address.")
        return ask_host(index, existing_names, existing_ips)

    memory = prompt_int(
        "Memory MiB",
        DEFAULT_MEMORY,
        minimum=512,
        maximum=131072,
    )

    vcpu = prompt_int(
        "vCPU",
        DEFAULT_VCPU,
        minimum=1,
        maximum=64,
    )

    return Host(
        name=name,
        ip=ip,
        memory=memory,
        vcpu=vcpu,
    )


def collect_hosts() -> list[Host]:
    hosts: list[Host] = []
    names: set[str] = set()
    ips: set[str] = set()

    index = 1

    while True:
        host = ask_host(index, names, ips)

        if host is None:
            break

        hosts.append(host)
        names.add(host.name)
        ips.add(host.ip)

        print(
            f"  Added {host.name} -> "
            f"{host.ip}, {host.memory} MiB, {host.vcpu} vCPU"
        )

        index += 1

    if not hosts:
        die("no hosts were specified")

    return hosts


def hcl_string(value: str) -> str:
    """
    Produce a safe Terraform/HCL double-quoted string.
    """
    escaped = (
        value
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )

    return f'"{escaped}"'


def generate_tfvars(
    hosts: list[Host],
    vm_prefix: str,
    vm_suffix: str,
) -> str:
    lines: list[str] = []

    lines.append("hosts = {")

    for host in hosts:
        lines.extend(
            [
                f"  {host.name} = {{",
                f"    ip     = {hcl_string(host.ip)}",
                f"    memory = {host.memory}",
                f"    vcpu   = {host.vcpu}",
                "  }",
                "",
            ]
        )

    lines.append("}")
    lines.append("")
    lines.append(
        f"bootstrap_password = {hcl_string(DEFAULT_BOOTSTRAP_PASSWORD)}"
    )
    lines.append("")
    lines.append(f"vm_name_prefix = {hcl_string(vm_prefix)}")
    lines.append(f"vm_name_suffix = {hcl_string(vm_suffix)}")
    lines.append("")

    return "\n".join(lines)


def write_atomic(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    fd, tmp_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        dir=path.parent,
        text=True,
    )

    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            tmp.write(content)
            tmp.flush()
            os.fsync(tmp.fileno())

        os.replace(tmp_name, path)

    except Exception:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass

        raise


def generate_inventory(hosts: list[Host]) -> str:
    lines = []

    for host in hosts:
        lines.append(f"{host.name}:")
        lines.append(f"  ansible_host: {host.ip}")

    lines.append("")

    return "\n".join(lines)


def run_command(
    command: list[str],
    *,
    description: str,
) -> bool:
    print(f"\n==> {description}")
    print("$", " ".join(command))

    result = subprocess.run(command)

    if result.returncode != 0:
        print(
            f"\nERROR: command failed with exit code "
            f"{result.returncode}: {' '.join(command)}",
            file=sys.stderr,
        )
        return False

    return True


def terraform_check() -> None:
    if not run_command(
        ["terraform", "fmt"],
        description="Formatting Terraform configuration",
    ):
        die("terraform fmt failed")

    if not run_command(
        ["terraform", "validate"],
        description="Validating Terraform configuration",
    ):
        die("terraform validate failed")

    if not run_command(
        ["terraform", "plan", "-input=false"],
        description="Creating Terraform plan",
    ):
        die("terraform plan failed")


def print_summary(
    hosts: list[Host],
    vm_prefix: str,
    vm_suffix: str,
) -> None:
    print("\n" + "=" * 70)
    print("Configuration")
    print("=" * 70)

    print(f"VM naming: {vm_prefix}-<hostname>-{vm_suffix}")
    print()

    print(
        f"{'Hostname':<20}"
        f"{'IP':<18}"
        f"{'Memory':<12}"
        f"{'vCPU':<8}"
        f"VM name"
    )

    print("-" * 70)

    for host in hosts:
        vm_name = f"{vm_prefix}-{host.name}-{vm_suffix}"

        print(
            f"{host.name:<20}"
            f"{host.ip:<18}"
            f"{host.memory:<12}"
            f"{host.vcpu:<8}"
            f"{vm_name}"
        )

    print("=" * 70)


def print_inventory(hosts: list[Host]) -> None:
    print("\n" + "=" * 70)
    print("Ansible inventory snippet")
    print("=" * 70)
    print()
    print(generate_inventory(hosts), end="")
    print("=" * 70)


def main() -> int:
    project_dir = Path(__file__).resolve().parent

    os.chdir(project_dir)

    if not Path("main.tf").exists():
        die("main.tf not found")

    if not Path("versions.tf").exists():
        die("versions.tf not found")

    print("=" * 70)
    print("mytfctl - my terraform ctl")
    print("=" * 70)

    vm_prefix, vm_suffix = ask_vm_naming()

    hosts = collect_hosts()

    print_summary(
        hosts,
        vm_prefix,
        vm_suffix,
    )

    print("\nThe configuration above will be written to terraform.tfvars.")

    answer = input("Continue? [Y/n]: ").strip().lower()

    if answer not in ("", "y", "yes"):
        print("Cancelled.")
        return 0

    tfvars_content = generate_tfvars(
        hosts,
        vm_prefix,
        vm_suffix,
    )

    tfvars_path = project_dir / "terraform.tfvars"

    try:
        write_atomic(tfvars_path, tfvars_content)
    except OSError as exc:
        die(f"cannot write {tfvars_path}: {exc}")

    print(f"\nGenerated {tfvars_path}")

    terraform_check()

    inventory_path = (
        project_dir / "ansible-inventory-snippet.yml"
    )

    try:
        write_atomic(
            inventory_path,
            generate_inventory(hosts),
        )
    except OSError as exc:
        die(f"cannot write {inventory_path}: {exc}")

    print_inventory(hosts)

    print(
        "\nTerraform plan completed successfully."
    )

    print(
        "\nNext step is deliberately left to you:"
    )
    print(
        "  terraform apply"
    )

    print(
        f"\nAnsible inventory snippet was saved to:"
        f"\n  {inventory_path}"
    )

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\n\nCancelled.")
        raise SystemExit(130)
