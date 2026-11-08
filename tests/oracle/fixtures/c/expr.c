int f(int a, int b) {
    int c = a + b * 2 - (a << 3) / b;
    c += a > b && b != 0 || !a;
    c = a ? b : c;
    return -c + ~a + sizeof(int) + (int)b;
}
