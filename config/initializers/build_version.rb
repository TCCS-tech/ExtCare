require "digest"

# Identical application code must report the same version across processes and
# replicas. Compute once at boot; no Git checkout or deployment variable needed.
digest = Digest::SHA256.new
Dir.chdir(Rails.root) do
  Dir.glob("{app,config,lib,public}/**/*").push("Gemfile.lock").sort.each do |path|
    next unless File.file?(path)
    next if path.start_with?("public/assets/")

    digest << path << "\0" << Digest::SHA256.file(path).hexdigest << "\0"
  end
end
Rails.application.config.x.build_version = digest.hexdigest
