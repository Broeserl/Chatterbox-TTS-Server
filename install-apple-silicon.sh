#!/bin/bash
# install-apple-silicon.sh - Automated Apple Silicon MPS Installation with Python 3.12 auto-install

set -e  # Exit on any error

echo "🍎 Starting Apple Silicon (MPS) Installation for Chatterbox TTS..."

# Function to check if Homebrew is installed
check_homebrew() {
    if command -v brew &> /dev/null; then
        echo "✅ Homebrew is installed" >&2
        return 0
    else
        echo "❌ Homebrew is not installed" >&2
        return 1
    fi
}

# Function to install Homebrew
install_homebrew() {
    echo "🍺 Installing Homebrew..." >&2
    echo "   This will install the package manager for macOS" >&2

    # Install Homebrew using the official installation script
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for the current session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        # Apple Silicon Mac
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        # Intel Mac
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    echo "✅ Homebrew installation completed" >&2
}

# Function to install Python 3.12 via Homebrew
install_python312() {
    echo "🐍 Installing Python 3.12 via Homebrew..." >&2

    # Update Homebrew first
    echo "   Updating Homebrew..." >&2
    brew update

    # Install Python 3.12
    echo "   Installing python@3.12..." >&2
    brew install python@3.12

    # Try to link python3.12 to make it available in PATH
    echo "   Setting up Python 3.12 paths..." >&2

    # Add Homebrew Python to PATH for current session
    if [[ -f "/opt/homebrew/bin/python3.12" ]]; then
        # Apple Silicon Mac
        export PATH="/opt/homebrew/bin:$PATH"
        echo "   Python 3.12 installed at: /opt/homebrew/bin/python3.12" >&2
    elif [[ -f "/usr/local/bin/python3.12" ]]; then
        # Intel Mac
        export PATH="/usr/local/bin:$PATH"
        echo "   Python 3.12 installed at: /usr/local/bin/python3.12" >&2
    fi

    # Verify installation and return the path
    if command -v python3.12 &> /dev/null; then
        local version=$(python3.12 --version 2>&1)
        echo "✅ Python 3.12 installed successfully: $version" >&2
        echo "python3.12"  # This is the return value
        return 0
    else
        echo "❌ Python 3.12 installation failed - command not found in PATH" >&2
        echo "🔍 Searching for Python 3.12 installation..." >&2

        # Search for python3.12 in common locations
        local python312_path=""
        for path in "/opt/homebrew/bin/python3.12" "/usr/local/bin/python3.12" "/usr/bin/python3.12"; do
            if [[ -f "$path" ]]; then
                python312_path="$path"
                echo "   Found Python 3.12 at: $path" >&2
                break
            fi
        done

        if [[ -n "$python312_path" ]]; then
            echo "✅ Python 3.12 found at: $python312_path" >&2
            echo "   Will use full path for installation" >&2
            echo "$python312_path"  # Return the full path
            return 0
        else
            return 1
        fi
    fi
}

# Function to check Python version compatibility
check_python_version() {
    local python_cmd="$1"

    if ! command -v "$python_cmd" &> /dev/null; then
        return 1  # Python command not found
    fi

    # Get Python version
    local version_output=$($python_cmd --version 2>&1)
    local version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

    if [[ -z "$version" ]]; then
        return 1  # Could not parse version
    fi

    # Split version into parts
    IFS='.' read -ra version_parts <<< "$version"
    local major=${version_parts[0]}
    local minor=${version_parts[1]}

    echo "   Found $python_cmd version: $version" >&2

    # Check if version is compatible (3.9 to 3.12)
    if [[ $major -eq 3 ]] && [[ $minor -ge 9 ]] && [[ $minor -le 12 ]]; then
        echo "   ✅ Compatible Python version" >&2
        return 0
    else
        echo "   ❌ Incompatible Python version (need Python 3.9-3.12)" >&2
        return 1
    fi
}

# Function to find or install compatible Python version
ensure_compatible_python() {
    echo "🐍 Ensuring compatible Python version is available..." >&2

    # First, try to find python3.12 in common locations (including Homebrew paths)
    echo "🔍 Searching for python3.12..." >&2

    local python312_candidates=(
        "python3.12"
        "/opt/homebrew/bin/python3.12"
        "/usr/local/bin/python3.12"
        "/usr/bin/python3.12"
    )

    for candidate in "${python312_candidates[@]}"; do
        if [[ -f "$candidate" ]] || command -v "$candidate" &> /dev/null; then
            echo "   Testing candidate: $candidate" >&2
            if check_python_version "$candidate"; then
                echo "$candidate"  # This is the return value
                return 0
            fi
        fi
    done

    # Try other Python commands
    local python_commands=(
        "python3.11"
        "python3.10"
        "python3.9"
        "python3"
        "python"
    )

    for cmd in "${python_commands[@]}"; do
        echo "🔍 Checking $cmd..." >&2
        if check_python_version "$cmd"; then
            echo "✅ Will use: $cmd" >&2
            echo "$cmd"  # This is the return value
            return 0
        fi
    done

    # No compatible Python found, offer to install Python 3.12
    echo "" >&2
    echo "❌ No compatible Python version found!" >&2
    echo "" >&2
    echo "📋 Requirements:" >&2
    echo "   • Python 3.9, 3.10, 3.11, or 3.12 (Python 3.13+ not yet supported by ONNX)" >&2
    echo "" >&2
    echo "💡 I can automatically install Python 3.12 for you using Homebrew." >&2
    echo "" >&2

    while true; do
        read -p "Would you like to install Python 3.12 automatically? (y/N): " -r
        case $REPLY in
            [Yy]*)
                # Check if Homebrew is installed
                if ! check_homebrew; then
                    echo "" >&2
                    echo "📦 Homebrew is required to install Python 3.12 automatically." >&2
                    read -p "Install Homebrew now? (y/N): " -r
                    case $REPLY in
                        [Yy]*)
                            install_homebrew
                            ;;
                        *)
                            echo "❌ Cannot install Python 3.12 without Homebrew" >&2
                            echo "📝 Manual installation options:" >&2
                            echo "   • Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
                            echo "   • Then run: brew install python@3.12" >&2
                            echo "   • Or download from python.org (choose 3.12.x version)" >&2
                            exit 1
                            ;;
                    esac
                fi

                # Install Python 3.12
                local python312_path=$(install_python312)
                if [[ $? -eq 0 && -n "$python312_path" ]]; then
                    echo "$python312_path"  # This is the return value
                    return 0
                else
                    echo "❌ Failed to install or locate Python 3.12" >&2
                    exit 1
                fi
                ;;
            [Nn]*|"")
                echo "❌ Cannot proceed without compatible Python version" >&2
                echo "" >&2
                echo "💡 Manual installation suggestions:" >&2
                echo "   • Using Homebrew: brew install python@3.12" >&2
                echo "   • Using pyenv: pyenv install 3.12.7 && pyenv global 3.12.7" >&2
                echo "   • Download from python.org (choose 3.12.x version)" >&2
                echo "" >&2
                echo "🔄 After installing compatible Python, run this script again." >&2
                exit 1
                ;;
            *)
                echo "Please answer yes (y) or no (n)." >&2
                ;;
        esac
    done
}

# Function to check if we're in a virtual environment
is_in_venv() {
    if [[ "$VIRTUAL_ENV" != "" ]] || [[ "$CONDA_DEFAULT_ENV" != "" ]]; then
        return 0  # In virtual environment
    else
        return 1  # Not in virtual environment
    fi
}

# Function to create and activate virtual environment
setup_venv() {
    local python_cmd="$1"
    local venv_name="venv-chatterbox-apple-silicon"

    echo "🐍 Setting up virtual environment with $python_cmd..."

    # Create virtual environment
    echo "   Creating virtual environment: $venv_name"
    "$python_cmd" -m venv "$venv_name"

    # Activate virtual environment
    echo "   Activating virtual environment..."
    source "$venv_name/bin/activate"

    # Verify Python version in venv
    local venv_python_version=$(python --version 2>&1)
    echo "   Virtual environment Python version: $venv_python_version"

    echo "✅ Virtual environment created and activated!"
    echo "📝 Virtual environment location: $(pwd)/$venv_name"
    echo "📝 To activate manually later: source $venv_name/bin/activate"
    echo "📝 To deactivate: deactivate"
    echo ""
}

# Ensure Homebrew PATH is available (in case user has Homebrew but PATH isn't updated)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    # Apple Silicon Mac
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
    # Intel Mac
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Find or install compatible Python version
echo "🔍 Checking Python compatibility..."
compatible_python=$(ensure_compatible_python)

echo ""
echo "🎯 Selected Python: $compatible_python"

# Verify the selected Python actually works
echo "🧪 Verifying selected Python..."
if [[ -f "$compatible_python" ]] || command -v "$compatible_python" &> /dev/null; then
    python_version_check=$($compatible_python --version 2>&1)
    echo "   ✅ Verified: $python_version_check"
else
    echo "   ❌ Selected Python is not accessible: $compatible_python"
    exit 1
fi

echo ""

# Check virtual environment status
if is_in_venv; then
    echo "✅ Virtual environment detected: $VIRTUAL_ENV"

    # Check if current venv Python version is compatible
    echo "🔍 Checking virtual environment Python version..."
    current_python_version=$(python --version 2>&1)
    echo "   Current venv Python: $current_python_version"

    # Extract version numbers for comparison
    current_version=$(echo "$current_python_version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [[ -n "$current_version" ]]; then
        IFS='.' read -ra version_parts <<< "$current_version"
        major=${version_parts[0]}
        minor=${version_parts[1]}

        if [[ $major -eq 3 ]] && [[ $minor -ge 13 ]]; then
            echo "   ❌ Current virtual environment uses Python $current_version"
            echo "   ⚠️  Python 3.13+ is not compatible with ONNX and other ML packages"
            echo ""
            echo "Options:"
            echo "1) Deactivate current venv and create new one with compatible Python ($compatible_python)"
            echo "2) Continue anyway (likely to fail at ONNX installation)"
            echo "3) Exit and manually fix Python version"

            while true; do
                read -p "Choose option (1/2/3): " choice
                case $choice in
                    1)
                        echo "Deactivating current virtual environment..."
                        deactivate 2>/dev/null || true
                        setup_venv "$compatible_python"
                        break
                        ;;
                    2)
                        echo "⚠️  Continuing with Python $current_version (expect ONNX installation to fail)..."
                        break
                        ;;
                    3)
                        echo "📝 To fix manually:"
                        echo "   1. deactivate"
                        echo "   2. Create new venv with: $compatible_python -m venv your-venv-name"
                        echo "   3. source your-venv-name/bin/activate"
                        echo "   4. Run this script again"
                        exit 0
                        ;;
                    *)
                        echo "Invalid choice. Please enter 1, 2, or 3."
                        ;;
                esac
            done
        else
            echo "   ✅ Virtual environment Python version is compatible"
        fi
    fi
    echo ""
else
    echo "⚠️  No virtual environment detected."
    echo ""
    echo "Options:"
    echo "1) Create a new virtual environment automatically (with $compatible_python)"
    echo "2) Continue without virtual environment (not recommended)"
    echo "3) Exit and set up virtual environment manually"
    echo ""

    while true; do
        read -p "Choose option (1/2/3): " choice
        case $choice in
            1)
                setup_venv "$compatible_python"
                break
                ;;
            2)
                echo "⚠️  Continuing without virtual environment..."
                echo "⚠️  This may cause conflicts with system Python packages!"
                break
                ;;
            3)
                echo "📝 To set up virtual environment manually:"
                echo "   $compatible_python -m venv venv-chatterbox"
                echo "   source venv-chatterbox/bin/activate"
                echo "   ./install-apple-silicon.sh"
                exit 0
                ;;
            *)
                echo "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
fi

# Check macOS version
echo "🔍 Checking system compatibility..."
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script is designed for macOS only"
    exit 1
fi

macos_version=$(sw_vers -productVersion)
echo "📱 Detected macOS version: $macos_version"

# Check if macOS version supports MPS (12.3+)
IFS='.' read -ra version_parts <<< "$macos_version"
major=${version_parts[0]}
minor=${version_parts[1]}

if [[ $major -gt 12 ]] || [[ $major -eq 12 && $minor -ge 3 ]]; then
    echo "✅ macOS version supports Metal Performance Shaders (MPS)"
else
    echo "⚠️  Warning: macOS 12.3 or later is recommended for MPS support"
    echo "   Your version: $macos_version"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

# Function to run pip command with error handling
run_pip_command() {
    local command="$1"
    local description="$2"

    echo "🔧 $description..."
    echo "   Running: $command"

    if $command; then
        echo "   ✅ Success"
    else
        echo "   ❌ Failed to execute: $command"

        # Special handling for ONNX installation failure
        if [[ "$command" == *"onnx"* ]]; then
            echo ""
            echo "💡 ONNX installation failed - this is likely due to Python version incompatibility"
            echo "   ONNX requires Python 3.9-3.12 (Python 3.13+ not yet supported)"
            current_python=$(python --version 2>&1)
            echo "   Your current Python: $current_python"
            echo ""
            echo "🔄 The script should have installed Python 3.12 - this may be a different issue."
            echo "   Please check the error messages above."
        fi

        exit 1
    fi
    echo ""
}

# Start installation process
echo "🚀 Beginning installation process..."
echo ""

# Show final Python version being used
final_python_version=$(python --version 2>&1)
echo "🐍 Using Python: $final_python_version"
echo ""

# Step 1: Upgrade pip and install PyTorch with MPS support
run_pip_command "pip install --upgrade pip" "Step 1a: Upgrading pip"
run_pip_command "pip install torch torchvision torchaudio" "Step 1b: Installing PyTorch with MPS support"

# Step 2: Install chatterbox without dependencies
run_pip_command "pip install --no-deps git+https://github.com/resemble-ai/chatterbox.git" "Step 2: Installing chatterbox-tts (without dependencies)"

# Step 3: Install core server dependencies
echo "🌐 Step 3: Installing core server dependencies..."
core_deps=(
    "fastapi"
    "'uvicorn[standard]'"
    "librosa"
    "safetensors"
    "soundfile"
    "pydub"
    "audiotsm"
    "praat-parselmouth"
    "python-multipart"
    "requests"
    "aiofiles"
    "PyYAML"
    "watchdog"
    "unidecode"
    "inflect"
    "tqdm"
)

for dep in "${core_deps[@]}"; do
    eval "run_pip_command 'pip install $dep' 'Installing $dep'"
done

# Step 4: Install chatterbox dependencies with specific versions
echo "🔗 Step 4: Installing chatterbox dependencies with pinned versions..."
chatterbox_deps=(
    "conformer==0.3.2"
    "diffusers==0.29.0"
    "resemble-perth==1.0.1"
    "transformers==4.46.3"
)

for dep in "${chatterbox_deps[@]}"; do
    run_pip_command "pip install $dep" "Installing $dep"
done

# Step 5: Install s3tokenizer without dependencies
run_pip_command "pip install --no-deps s3tokenizer" "Step 5: Installing s3tokenizer (without dependencies)"

# Step 6: Install compatible ONNX version (this is where Python 3.13 fails)
echo "⚠️  Installing ONNX - this requires Python 3.9-3.12 (fails on Python 3.13+)"
run_pip_command "pip install onnx==1.16.0" "Step 6: Installing compatible ONNX version"

# Installation complete
echo "🎉 Installation completed successfully!"
echo ""
echo "📝 Next steps:"
echo "   1. Update your config.yaml to set 'tts_engine.device' to 'mps'"
echo "   2. Test MPS functionality with: python -c \"import torch; print('MPS available:', torch.backends.mps.is_available())\""

# Show current environment info
if is_in_venv; then
    echo "   3. Your virtual environment is active: $VIRTUAL_ENV"
    echo "      To deactivate later: deactivate"
    echo "      To reactivate: source $(basename "$VIRTUAL_ENV")/bin/activate"
fi

echo ""
echo "🚀 You can now run your Chatterbox TTS server with Apple Silicon acceleration!"

# Optional: Test MPS availability and installation
echo ""
read -p "🧪 Would you like to test the installation now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔍 Testing installation..."
    python -c "
import sys
import torch

print(f'✅ Python version: {sys.version}')
print(f'✅ PyTorch version: {torch.__version__}')
print(f'✅ MPS available: {torch.backends.mps.is_available()}')
print(f'✅ MPS built: {torch.backends.mps.is_built()}')

if torch.backends.mps.is_available():
    try:
        # Test basic MPS functionality
        x = torch.tensor([1.0, 2.0, 3.0]).to('mps')
        y = x * 2
        result = y.cpu()
        print(f'✅ MPS test successful: {result.tolist()}')
        print('🎉 Apple Silicon MPS acceleration is ready!')
    except Exception as e:
        print(f'⚠️  MPS test failed: {e}')
        print('   You may need to restart your terminal or check your macOS version.')
else:
    print('⚠️  MPS is not available. Check that you have macOS 12.3+ and Apple Silicon.')

# Test ONNX import
try:
    import onnx
    print(f'✅ ONNX version: {onnx.__version__}')
    print('✅ ONNX imported successfully')
except ImportError as e:
    print(f'❌ ONNX import failed: {e}')

# Test chatterbox import
try:
    from chatterbox.mtl_tts import ChatterboxMultilingualTTS
    print('✅ Chatterbox TTS imported successfully')
except ImportError as e:
    print(f'⚠️  Chatterbox import failed: {e}')
    print('   This may be normal if additional setup is required')
"
fi

echo ""
echo "Happy TTS generation! 🎤✨"
echo ""
echo "📋 Installation Summary:"
echo "   • Python version used: $(python --version 2>&1)"
echo "   • Homebrew: $(if command -v brew &> /dev/null; then echo 'Installed'; else echo 'Not installed'; fi)"
echo "   • Virtual environment: $(if is_in_venv; then echo 'Active'; else echo 'Not active'; fi)"
echo "   • Ready for Apple Silicon MPS acceleration!"