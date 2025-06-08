# Python development shell
{ pkgs, ... }:

{
  devShells.python = pkgs.mkShell {
    name = "python-development";
    
    packages = with pkgs; [
      python3
      python3Packages.pip
      python3Packages.virtualenv
      pipenv
      poetry
      python3Packages.black
      python3Packages.flake8
      python3Packages.mypy
      python3Packages.pytest
      python3Packages.ipython
      python3Packages.jupyter
      python3Packages.requests
      python3Packages.click
      python3Packages.rich
      pyright
    ];
    
    shellHook = ''
      echo "🐍 Python Development Environment"
      echo "🔧 python3, pip, poetry, black, flake8, mypy available"
      echo "📦 Additional tools: pytest, ipython, jupyter, pyright"
      
      # Set up Python environment
      export PYTHONPATH="$PWD:$PYTHONPATH"
      export PIP_PREFIX="$PWD/.pip"
      export PATH="$PIP_PREFIX/bin:$PATH"
      
      # Create local pip directory if it doesn't exist
      mkdir -p .pip/bin
      
      # Helpful aliases
      alias py="python3"
      alias pip="python3 -m pip"
      alias venv="python3 -m venv"
      alias pytest="python3 -m pytest"
      alias black="python3 -m black"
      alias flake8="python3 -m flake8"
      alias mypy="python3 -m mypy"
      
      echo "💡 Create virtual environment: python3 -m venv venv && source venv/bin/activate"
    '';
  };
}