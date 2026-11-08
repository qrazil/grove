void run(int n) {
    for (int i = 0; i < n; i++) {
        if (i % 2 == 0) continue;
        else if (i > 10) break;
        while (n--) { n -= 1; }
    }
    switch (n) {
    case 1:
        n = 2;
        break;
    default:
        goto done;
    }
    do { n++; } while (n < 3);
done:
    return;
}
