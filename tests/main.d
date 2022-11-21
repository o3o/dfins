import unit_threaded.runner.runner;

int main(string[] args) {
    return runTests!(
          "ut.util",
          "ut.fins",
          "dfins.util",
          "dfins.channel",
          "dfins.fins",
          )(args);
}
