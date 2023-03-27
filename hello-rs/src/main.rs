use clap::Parser;

#[derive(Debug, Parser)]
struct Args {
    #[arg(short, long)]
    name: String,
}

fn main() {
    let args = Args::parse();
    let name = args.name;
    println!("Hello, {name}!");
}
