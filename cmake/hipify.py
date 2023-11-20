import argparse
import os
import re
import subprocess


def hipify(perl_path, hipify_perl_path, src_file_path, dst_file_path):
  dir_name = os.path.dirname(dst_file_path)
  if not os.path.exists(dir_name):
    os.makedirs(dir_name, exist_ok=True)

  # Run hipify-perl first, capture output
  s = subprocess.run([perl_path, hipify_perl_path, src_file_path],
                     stdout=subprocess.PIPE,
                     text=True,
                     check=False).stdout

  s = "#include <hip/hip_runtime.h>\n" + s

  # patch includes
  # s = s.replace("#include <cute/", "#include <hute/")
  # s = s.replace('#include "cute/', '#include "hute/')
  s = s.replace("/cuda_types.hpp>\n", "/rocm_types.hpp>\n")
  # s = re.sub(r'^#include ?(<|").*_sm(61|70|75|80|90).*\.hpp("|>)$', "", s, flags=re.MULTILINE)
  s = re.sub(r'^#include ?(<|").*_sm(90).*\.hpp("|>)$', "", s, flags=re.MULTILINE)

  # patch namespace
  # s = s.replace("namespace cute", "namespace hute")
  # s = s.replace("cute::", "hute::")

  # patch for misc language features
  s = s.replace(" __align__(", " alignas(")

  with open(dst_file_path, "w") as f:
    f.write(s)


if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument("--perl", required=True)
  parser.add_argument("--hipify_perl", required=True)
  parser.add_argument("--output", "-o", help="output file")
  parser.add_argument("src", help="src")
  args = parser.parse_args()

  hipify(args.perl, args.hipify_perl, args.src, args.output)
