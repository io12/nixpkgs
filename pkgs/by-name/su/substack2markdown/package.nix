{
  lib,
  fetchFromGitHub,
  python3,
  makeWrapper,
}:

let
  pythonDeps = with python3.pkgs; [
    beautifulsoup4
    html2text
    markdown
    requests
    selenium
    tqdm
    webdriver-manager
  ];
in
python3.pkgs.buildPythonApplication {
  pname = "substack2markdown";
  version = "2.1.0-unstable-2026-07-06";
  pyproject = false;

  src = fetchFromGitHub {
    # Use io12's fork rather than upstream: it adds SUBSTACK_EMAIL/
    # SUBSTACK_PASSWORD environment variable support (submitted upstream at
    # https://github.com/timf34/Substack2Markdown/pull/new/env-var-credentials),
    # which is required for premium/login scraping to be usable at all from
    # a read-only Nix store install, since there is otherwise no way to
    # supply credentials other than editing config.py in the source tree.
    owner = "io12";
    repo = "Substack2Markdown";
    rev = "90ee263016de9ac9cc14a38c470aa718e3218dd0";
    hash = "sha256-OWLUbf7rWLEJPp15F/V3A+Q3oC2zxAs+lWB6wM3fAnM=";
  };

  __structuredAttrs = true;

  build-system = [ makeWrapper ];

  dependencies = pythonDeps;

  nativeCheckInputs = with python3.pkgs; [
    pytestCheckHook
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/substack2markdown
    cp substack_scraper.py $out/share/substack2markdown/
    # config.py is optional (its import is caught), but ship it anyway
    # since it's harmless and only contains placeholder credentials.
    # Real credentials should be set via the SUBSTACK_EMAIL and
    # SUBSTACK_PASSWORD environment variables instead of editing this
    # file, which isn't possible from the read-only Nix store.
    cp config.py $out/share/substack2markdown/

    runHook postInstall
  '';

  fixupPhase = ''
    runHook preFixup

    makeWrapper ${python3.interpreter} $out/bin/substack2markdown \
      --set PYTHONPATH "$out/share/substack2markdown:${python3.pkgs.makePythonPath pythonDeps}" \
      --add-flags "$out/share/substack2markdown/substack_scraper.py"

    runHook postFixup
  '';

  meta = {
    description = "Download free Substack posts and convert them to Markdown and HTML";
    homepage = "https://github.com/timf34/Substack2Markdown";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ io12 ];
    mainProgram = "substack2markdown";
  };
}
