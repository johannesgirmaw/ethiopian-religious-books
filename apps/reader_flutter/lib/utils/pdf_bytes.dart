/// True when [bytes] begins with the PDF magic header `%PDF-`.
bool pdfBytesLookValid(List<int> bytes) {
  if (bytes.length < 5) return false;
  return bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46 &&
      bytes[4] == 0x2D;
}
