require 'irb_util'

rr = (
    /^.git$/ |
    /^.git\// |

    /\/.git$/ |
    /\/.git\//
)

".gitfoo/blah" =~ rr
