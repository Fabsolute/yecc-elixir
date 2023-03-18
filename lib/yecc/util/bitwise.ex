defmodule Yecc.Util.Bitwise do
  import Bitwise

  def set_add(num, bm) do
    import Bitwise
    1 <<< num ||| bm
  end

  def set_union(bm1, bm2) do
    import Bitwise
    bm1 ||| bm2
  end

  def empty_member(bm) do
    set_member(0, bm)
  end

  def empty_delete(bm) do
    set_delete(0, bm)
  end

  def set_member(num, bm) do
    (1 <<< num &&& bm) != 0
  end

  def set_delete(num, bm) do
    bxor(1 <<< num, bm)
  end

  def set_is_subset(bm1, bm2) do
    (bm1 &&& bm2) == bm1
  end
end
