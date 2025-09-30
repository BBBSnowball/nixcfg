{ ... }:
{
  services.ollama = {
    enable = true;
    #acceleration = "rocm";  #FIXME
  };

  services.nextjs-ollama-llm-ui = {
    enable = true;
  };

  #services.tabby.enable = true;
}
