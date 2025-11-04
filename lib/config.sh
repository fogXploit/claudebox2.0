#!/usr/bin/env bash
# Configuration management including INI files and profile definitions.

# -------- INI file helpers ----------------------------------------------------
_read_ini() {               # $1=file $2=section $3=key
  awk -F' *= *' -v s="[$2]" -v k="$3" '
    $0==s {in=1; next}
    /^\[/ {in=0}
    in && $1==k {print $2; exit}
  ' "$1" 2>/dev/null
}


# -------- Profile functions (Bash 3.2 compatible) -----------------------------
get_profile_packages() {
    case "$1" in
        core) echo "gcc g++ make git pkg-config libssl-dev libffi-dev zlib1g-dev tmux" ;;
        build-tools) echo "cmake ninja-build autoconf automake libtool" ;;
        shell) echo "rsync openssh-client man-db gnupg2 aggregate file" ;;
        networking) echo "iptables ipset iproute2 dnsutils" ;;
        c) echo "gdb valgrind clang clang-format clang-tidy cppcheck doxygen libboost-all-dev libcmocka-dev libcmocka0 lcov libncurses5-dev libncursesw5-dev" ;;
        openwrt) echo "rsync libncurses5-dev zlib1g-dev gawk gettext xsltproc libelf-dev ccache subversion swig time qemu-system-arm qemu-system-aarch64 qemu-system-mips qemu-system-x86 qemu-utils" ;;
        rust) echo "" ;;  # Rust installed via rustup
        python) echo "" ;;  # Managed via uv
        go) echo "" ;;  # Installed from tarball
        flutter) echo "" ;;  # Installed from source
        javascript) echo "" ;;  # Installed via nvm
        java) echo "" ;;  # Java installed via SDKMan, build tools in profile function
        ruby) echo "ruby-full ruby-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common" ;;
        php) echo "php php-cli php-fpm php-mysql php-pgsql php-sqlite3 php-curl php-gd php-mbstring php-xml php-zip composer" ;;
        database) echo "postgresql-client mysql-client sqlite3 redis-tools mongodb-clients" ;;
        devops) echo "docker.io docker-compose kubectl helm terraform ansible awscli" ;;
        web) echo "nginx apache2-utils httpie" ;;
        embedded) echo "gcc-arm-none-eabi gdb-multiarch openocd picocom minicom screen" ;;
        datascience) echo "r-base" ;;
        security) echo "nmap tcpdump wireshark-common netcat-openbsd john hashcat hydra" ;;
        ml) echo "" ;;  # Just cmake needed, comes from build-tools now
        *) echo "" ;;
    esac
}

get_profile_description() {
    case "$1" in
        core) echo "Core Development Utilities (compilers, VCS, shell tools)" ;;
        build-tools) echo "Build Tools (CMake, autotools, Ninja)" ;;
        shell) echo "Optional Shell Tools (fzf, SSH, man, rsync, file)" ;;
        networking) echo "Network Tools (IP stack, DNS, route tools)" ;;
        c) echo "C/C++ Development (debuggers, analyzers, Boost, ncurses, cmocka)" ;;
        openwrt) echo "OpenWRT Development (cross toolchain, QEMU, distro tools)" ;;
        rust) echo "Rust Development (installed via rustup)" ;;
        python) echo "Python Development (managed via uv)" ;;
        go) echo "Go Development (installed from upstream archive)" ;;
        flutter) echo "Flutter Development (installed from fvm)" ;;
        javascript) echo "JavaScript/TypeScript (Node installed via nvm)" ;;
        java) echo "Java Development (latest LTS, Maven, Gradle, Ant via SDKMan)" ;;
        ruby) echo "Ruby Development (gems, native deps, XML/YAML)" ;;
        php) echo "PHP Development (PHP + extensions + Composer)" ;;
        database) echo "Database Tools (clients for major databases)" ;;
        devops) echo "DevOps Tools (Docker, Kubernetes, Terraform, etc.)" ;;
        web) echo "Web Dev Tools (nginx, HTTP test clients)" ;;
        embedded) echo "Embedded Dev (ARM toolchain, serial debuggers)" ;;
        datascience) echo "Data Science (Python, Jupyter, R)" ;;
        security) echo "Security Tools (scanners, crackers, packet tools)" ;;
        ml) echo "Machine Learning (build layer only; Python via uv)" ;;
        *) echo "" ;;
    esac
}

get_all_profile_names() {
    echo "core build-tools shell networking c openwrt rust python go flutter javascript java ruby php database devops web embedded datascience security ml"
}

profile_exists() {
    local profile="$1"
    for p in $(get_all_profile_names); do
        [[ "$p" == "$profile" ]] && return 0
    done
    return 1
}

expand_profile() {
    case "$1" in
        c) echo "core build-tools c" ;;
        openwrt) echo "core build-tools openwrt" ;;
        ml) echo "core build-tools ml" ;;
        rust|go|flutter|python|php|ruby|java|database|devops|web|embedded|datascience|security|javascript)
            echo "core $1"
            ;;
        shell|networking|build-tools|core)
            echo "$1"
            ;;
        *)
            echo "$1"
            ;;
    esac
}

# -------- Profile file management ---------------------------------------------
get_profile_file_path() {
    # Use the parent directory name, not the slot name
    local parent_name=$(generate_parent_folder_name "$PROJECT_DIR")
    local parent_dir="$HOME/.claudebox/projects/$parent_name"
    mkdir -p "$parent_dir"
    echo "$parent_dir/profiles.ini"
}

read_config_value() {
    local config_file="$1"
    local section="$2"
    local key="$3"

    [[ -f "$config_file" ]] || return 1

    awk -F ' *= *' -v section="[$section]" -v key="$key" '
        $0 == section { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && $1 == key { print $2; exit }
    ' "$config_file"
}

read_profile_section() {
    local profile_file="$1"
    local section="$2"
    local result=()

    if [[ -f "$profile_file" ]] && grep -q "^\[$section\]" "$profile_file"; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^\[.*\]$ ]] && break
            result+=("$line")
        done < <(sed -n "/^\[$section\]/,/^\[/p" "$profile_file" | tail -n +2 | grep -v '^\[')
    fi

    printf '%s\n' "${result[@]:-}"
}

update_profile_section() {
    local profile_file="$1"
    local section="$2"
    shift 2
    local new_items=("$@")

    local existing_items=()
    readarray -t existing_items < <(read_profile_section "$profile_file" "$section")

    local all_items=()
    for item in "${existing_items[@]:-}"; do
        [[ -n "$item" ]] && all_items+=("$item")
    done

    for item in "${new_items[@]:-}"; do
        local found=false
        for existing in "${all_items[@]:-}"; do
            [[ "$existing" == "$item" ]] && found=true && break
        done
        [[ "$found" == "false" ]] && all_items+=("$item")
    done

    {
        if [[ -f "$profile_file" ]]; then
            awk -v sect="$section" '
                BEGIN { in_section=0; skip_section=0 }
                /^\[/ {
                    if ($0 == "[" sect "]") { skip_section=1; in_section=1 }
                    else { skip_section=0; in_section=0 }
                }
                !skip_section { print }
                /^\[/ && !skip_section && in_section { in_section=0 }
            ' "$profile_file"
        fi

        echo "[$section]"
        for item in "${all_items[@]:-}"; do
            echo "$item"
        done
        echo ""
    } > "${profile_file}.tmp"

    if [[ -f "${profile_file}.tmp" ]]; then
        mv "${profile_file}.tmp" "$profile_file"
    fi
}

get_current_profiles() {
    local profiles_file="${PROJECT_PARENT_DIR:-$HOME/.claudebox/projects/$(generate_parent_folder_name "$PWD")}/profiles.ini"
    local current_profiles=()

    if [[ -f "$profiles_file" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && current_profiles+=("$line")
        done < <(read_profile_section "$profiles_file" "profiles")
    fi

    printf '%s\n' "${current_profiles[@]}"
}

# Update or add a version for a specific profile
update_profile_version() {
    local profile_file="$1"
    local profile_name="$2"
    local version="$3"

    # Create file if it doesn't exist
    if [[ ! -f "$profile_file" ]]; then
        touch "$profile_file"
    fi

    # Check if [versions] section exists
    local has_versions_section=false
    if grep -q "^\[versions\]" "$profile_file"; then
        has_versions_section=true
    fi

    # Create temp file
    local temp_file="${profile_file}.tmp"

    if [[ "$has_versions_section" == "true" ]]; then
        # Update existing version or add new one
        local version_updated=false
        local in_versions_section=false

        while IFS= read -r line; do
            if [[ "$line" == "[versions]" ]]; then
                echo "$line"
                in_versions_section=true
            elif [[ "$line" =~ ^\[.*\]$ ]]; then
                # Entering a new section
                if [[ "$in_versions_section" == "true" ]] && [[ "$version_updated" == "false" ]]; then
                    # Add version before new section
                    echo "${profile_name}=${version}"
                    version_updated=true
                fi
                in_versions_section=false
                echo "$line"
            elif [[ "$in_versions_section" == "true" ]] && [[ "$line" == "${profile_name}="* ]]; then
                # Update existing version
                echo "${profile_name}=${version}"
                version_updated=true
            else
                echo "$line"
            fi
        done < "$profile_file" > "$temp_file"

        # If version wasn't updated, append to end of file
        if [[ "$version_updated" == "false" ]]; then
            echo "${profile_name}=${version}" >> "$temp_file"
        fi
    else
        # No [versions] section exists, create it
        cat "$profile_file" > "$temp_file"
        echo "" >> "$temp_file"
        echo "[versions]" >> "$temp_file"
        echo "${profile_name}=${version}" >> "$temp_file"
    fi

    mv "$temp_file" "$profile_file"
}

# Get version for a specific profile
get_profile_version() {
    local profile_file="$1"
    local profile_name="$2"

    if [[ ! -f "$profile_file" ]]; then
        echo ""
        return
    fi

    # Read version from [versions] section
    read_config_value "$profile_file" "versions" "$profile_name"
}

# -------- Custom mounts from .claudebox.yml ----------------------------------
# Parse .claudebox.yml and extract mounts
# Returns mounts in format: host:container:mode (e.g., /home/user/data:/data:rw)
parse_claudebox_yaml_mounts() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        return
    fi

    # Simple YAML parser for mounts section
    # Expected format:
    # mounts:
    #   - host: ~/data
    #     container: /data
    #     readonly: false
    awk '
        /^mounts:/ { in_mounts=1; next }
        /^[^ ]/ && in_mounts { in_mounts=0 }
        in_mounts && /^  - host:/ {
            gsub(/^  - host: */, "")
            gsub(/^["'\''"]|["'\''""]$/, "")  # Remove quotes
            host=$0
            getline
            if (/^    container:/) {
                gsub(/^    container: */, "")
                gsub(/^["'\''"]|["'\''""]$/, "")
                container=$0
                readonly="false"
                getline
                if (/^    readonly:/) {
                    gsub(/^    readonly: */, "")
                    readonly=$0
                }
                # Expand ~ to home directory
                gsub(/^~/, ENVIRON["HOME"], host)
                mode = (readonly == "true" || readonly == "yes") ? "ro" : "rw"
                print host ":" container ":" mode
            }
        }
    ' "$yaml_file"
}

# Parse CLI mount arguments
# Format: --mount ~/data:/data:rw or --mount ~/data:/data:ro
# Returns mounts in same format as parse_claudebox_yaml_mounts
parse_cli_mount() {
    local mount_spec="$1"

    # Split on colons
    local host=""
    local container=""
    local mode="rw"

    # Parse mount_spec (host:container[:mode])
    if [[ "$mount_spec" == *:*:* ]]; then
        host="${mount_spec%%:*}"
        local rest="${mount_spec#*:}"
        container="${rest%%:*}"
        mode="${rest#*:}"
    elif [[ "$mount_spec" == *:* ]]; then
        host="${mount_spec%%:*}"
        container="${mount_spec#*:}"
        mode="rw"
    else
        # Invalid format
        return 1
    fi

    # Expand ~ to home directory
    host="${host/#\~/$HOME}"

    # Validate mode
    if [[ "$mode" != "rw" ]] && [[ "$mode" != "ro" ]]; then
        printf "Invalid mount mode: %s (must be 'rw' or 'ro')\n" "$mode" >&2
        return 1
    fi

    printf '%s:%s:%s\n' "$host" "$container" "$mode"
}

# Merge mounts from config file and CLI (CLI overrides config for same container path)
# Arguments: config_mounts_array cli_mounts_array
# Outputs merged mounts
merge_mounts() {
    local config_mounts=("$@")

    # Use associative array simulation for Bash 3.2
    # Store mounts by container path to handle overrides
    local all_mounts=()
    local mount_keys=()

    # Add config mounts first
    for mount in "${config_mounts[@]:-}"; do
        if [[ -n "$mount" ]]; then
            local container_path="${mount#*:}"
            container_path="${container_path%%:*}"

            # Check if this container path already exists
            local found=false
            local i=0
            for key in "${mount_keys[@]:-}"; do
                if [[ "$key" == "$container_path" ]]; then
                    # Override existing mount
                    all_mounts[i]="$mount"
                    found=true
                    break
                fi
                i=$((i + 1))
            done

            if [[ "$found" == "false" ]]; then
                mount_keys+=("$container_path")
                all_mounts+=("$mount")
            fi
        fi
    done

    # Output all mounts
    printf '%s\n' "${all_mounts[@]:-}"
}

# -------- Profile installation functions for Docker builds -------------------
get_profile_core() {
    local packages=$(get_profile_packages "core")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_build_tools() {
    local packages=$(get_profile_packages "build-tools")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_shell() {
    local packages=$(get_profile_packages "shell")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_networking() {
    local packages=$(get_profile_packages "networking")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_c() {
    local packages=$(get_profile_packages "c")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_openwrt() {
    local packages=$(get_profile_packages "openwrt")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_rust() {
    cat << 'EOF'
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/claude/.cargo/bin:$PATH"
EOF
}

get_profile_python() {
    cat << 'EOF'
# Python profile - uv already installed in base image
# Python venv and dev tools are managed via entrypoint flag system
EOF
}

get_profile_go() {
    cat << 'EOF'
RUN wget -O go.tar.gz https://golang.org/dl/go1.21.0.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz
ENV PATH="/usr/local/go/bin:$PATH"
EOF
}

get_profile_flutter() {
    local flutter_version="${FLUTTER_SDK_VERSION:-stable}"
    cat << EOF
USER claude
RUN curl -fsSL https://fvm.app/install.sh | bash
ENV PATH="/usr/local/bin:$PATH"
RUN fvm install $flutter_version
RUN fvm global $flutter_version
ENV PATH="/home/claude/fvm/default/bin:$PATH"
RUN flutter doctor
USER root
EOF
}

get_profile_javascript() {
    cat << 'EOF'
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
ENV NVM_DIR="/home/claude/.nvm"
RUN . $NVM_DIR/nvm.sh && nvm install --lts
USER claude
RUN bash -c "source $NVM_DIR/nvm.sh && npm install -g typescript eslint prettier yarn pnpm"
USER root
EOF
}

get_profile_java() {
    cat << 'EOF'
USER claude
RUN curl -s "https://get.sdkman.io?ci=true" | bash
RUN bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && sdk install java && sdk install maven && sdk install gradle && sdk install ant"
USER root
# Create symlinks for all Java tools in system PATH
RUN for tool in java javac jar jshell; do \
        ln -sf /home/claude/.sdkman/candidates/java/current/bin/$tool /usr/local/bin/$tool; \
    done && \
    ln -sf /home/claude/.sdkman/candidates/maven/current/bin/mvn /usr/local/bin/mvn && \
    ln -sf /home/claude/.sdkman/candidates/gradle/current/bin/gradle /usr/local/bin/gradle && \
    ln -sf /home/claude/.sdkman/candidates/ant/current/bin/ant /usr/local/bin/ant
# Set JAVA_HOME environment variable
ENV JAVA_HOME="/home/claude/.sdkman/candidates/java/current"
ENV PATH="/home/claude/.sdkman/candidates/java/current/bin:$PATH"
EOF
}

get_profile_ruby() {
    local packages=$(get_profile_packages "ruby")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_php() {
    local packages=$(get_profile_packages "php")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_database() {
    local packages=$(get_profile_packages "database")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_devops() {
    local packages=$(get_profile_packages "devops")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_web() {
    local packages=$(get_profile_packages "web")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_embedded() {
    local packages=$(get_profile_packages "embedded")
    if [[ -n "$packages" ]]; then
        cat << 'EOF'
RUN apt-get update && apt-get install -y gcc-arm-none-eabi gdb-multiarch openocd picocom minicom screen && apt-get clean
USER claude
RUN ~/.local/bin/uv tool install platformio
USER root
EOF
    fi
}

get_profile_datascience() {
    local packages=$(get_profile_packages "datascience")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_security() {
    local packages=$(get_profile_packages "security")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_ml() {
    # ML profile just needs build tools which are dependencies
    echo "# ML profile uses build-tools for compilation"
}

export -f _read_ini get_profile_packages get_profile_description get_all_profile_names profile_exists expand_profile
export -f get_profile_file_path read_config_value read_profile_section update_profile_section get_current_profiles
export -f update_profile_version get_profile_version
export -f parse_claudebox_yaml_mounts parse_cli_mount merge_mounts
export -f get_profile_core get_profile_build_tools get_profile_shell get_profile_networking get_profile_c get_profile_openwrt
export -f get_profile_rust get_profile_python get_profile_go get_profile_flutter get_profile_javascript get_profile_java get_profile_ruby
export -f get_profile_php get_profile_database get_profile_devops get_profile_web get_profile_embedded get_profile_datascience
export -f get_profile_security get_profile_ml