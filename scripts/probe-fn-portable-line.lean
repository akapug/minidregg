import Host.Main

open Minidregg.Host

def zeros (count : Nat) : String := String.ofList (List.replicate count '0')

def validLine : String :=
  "fn-portable-v1 " ++ zeros 64 ++ " " ++ zeros 96 ++ " " ++ zeros 64 ++
  " " ++ zeros 3904 ++ " 41\n"

def refused (line : String) : Bool :=
  match parseFnPortableLine line with
  | .error _ => true
  | .ok _ => false

theorem valid_line_accepted : refused validLine = false := by native_decide
theorem trailing_junk_refused : refused (validLine ++ "junk") = true := by native_decide
theorem other_version_refused :
    refused (validLine.replace "fn-portable-v1" "fn-portable-v2") = true := by native_decide
theorem extra_field_refused : refused (validLine.replace " 41\n" " 41 extra\n") = true := by
  native_decide
theorem missing_newline_refused : refused (validLine.replace " 41\n" " 41") = true := by
  native_decide
theorem non_decimal_count_refused : refused (validLine.replace " 41\n" " 4A\n") = true := by
  native_decide
theorem short_payload_refused : refused (validLine.replace (zeros 3904) (zeros 3902)) = true := by
  native_decide
#assert_compiled valid_line_accepted
#assert_compiled trailing_junk_refused
#assert_compiled other_version_refused
#assert_compiled extra_field_refused
#assert_compiled missing_newline_refused
#assert_compiled non_decimal_count_refused
#assert_compiled short_payload_refused
