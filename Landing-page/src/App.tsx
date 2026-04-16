import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Separator } from "@/components/ui/separator"
import "./App.css"

const screenshots = [
  {
    title: "Home",
    src: "https://github.com/user-attachments/assets/f848d4fb-47eb-422a-b1f8-f5c571c8aee6",
  },
  {
    title: "History",
    src: "https://github.com/user-attachments/assets/58437d59-842c-41d2-80b2-c7a305968ecd",
  },
  {
    title: "Settings",
    src: "https://github.com/user-attachments/assets/1850903a-5cc6-400d-8735-04634737ed6c",
  },
  {
    title: "Inspector",
    src: "https://github.com/user-attachments/assets/8e108c94-98c4-4f30-836c-35d7ed75ce8e",
  },
  {
    title: "Bookmarks",
    src: "https://github.com/user-attachments/assets/6ca33a0a-c938-474b-8929-1538fb5cf7e7",
  },
  {
    title: "Code Appearance",
    src: "https://github.com/user-attachments/assets/e2ed8c22-0612-4d70-b284-ddac7bd0474b",
  },
]

const features = [
  "Live object inspection",
  "History and bookmarks",
  "Save, share, and export",
]

function App() {
  return (
    <main className="dark min-h-svh bg-background text-foreground">
      <div className="mx-auto flex w-full max-w-6xl flex-col gap-10 px-5 py-6 md:px-8 lg:py-8">
        <nav className="flex items-center justify-between">
          <a className="flex items-center gap-3" href="/" aria-label="Runtime Headers">
            <img
              className="size-10 rounded-md ring-1 ring-border"
              src="https://github.com/user-attachments/assets/c32404fb-12ab-4335-b764-4b391e24374e"
              alt=""
            />
            <span className="text-sm font-medium tracking-normal">Runtime Headers</span>
          </a>
          <div className="flex items-center gap-2">
            <Button
              variant="ghost"
              size="sm"
              render={<a href="https://github.com/AbodiDawoud/RuntimeHeaders" />}
            >
              GitHub
            </Button>
            <Button variant="outline" size="sm" render={<a href="https://buymeacoffee.com/abodi" />}>
              <img
                className="h-4 w-auto"
                src="https://cdn.buymeacoffee.com/buttons/bmc-new-btn-logo.svg"
                alt=""
                data-icon="inline-start"
              />
              Support
            </Button>
          </div>
        </nav>

        <section className="grid min-h-[calc(100svh-7rem)] items-center gap-8 lg:grid-cols-[0.95fr_1.05fr]">
          <div className="flex max-w-xl flex-col gap-6">
            <div className="flex flex-wrap gap-2">
              <Badge variant="secondary">iOS 17+</Badge>
              <Badge variant="outline">Swift 5</Badge>
              <Badge variant="outline">MIT License</Badge>
            </div>
            <div className="flex flex-col gap-4">
              <h1 className="text-4xl font-semibold tracking-normal text-balance md:text-6xl">
                Browse iOS runtime internals with a clean native inspector.
              </h1>
              <p className="max-w-lg text-base leading-7 text-muted-foreground md:text-lg">
                Runtime Headers lists public and private frameworks, dynamic libraries,
                classes, protocols, and selectors, then lets you dump binary headers for
                deeper iPhone and iPadOS exploration.
              </p>
            </div>
            <div className="flex flex-wrap gap-3">
              <Button render={<a href="https://github.com/AbodiDawoud/RuntimeHeaders" />}>
                GitHub Repository
              </Button>
              <Button variant="outline" render={<a href="#screenshots" />}>
                View Screenshots
              </Button>
            </div>
            <div className="grid gap-3 sm:grid-cols-3">
              {features.map((feature) => (
                <Card key={feature} size="sm" className="rounded-lg bg-card/80">
                  <CardHeader>
                    <CardTitle>{feature}</CardTitle>
                  </CardHeader>
                </Card>
              ))}
            </div>
          </div>

          <div className="relative min-h-[430px] overflow-hidden rounded-lg border bg-card/50 p-4">
            <div className="grid h-full grid-cols-[0.85fr_1fr] gap-4">
              <img
                className="h-[430px] w-full rounded-md object-cover object-top shadow-2xl"
                src="https://github.com/user-attachments/assets/f848d4fb-47eb-422a-b1f8-f5c571c8aee6"
                alt="Runtime Headers home screen"
              />
              <div className="flex flex-col gap-4">
                <img
                  className="h-[207px] w-full rounded-md object-cover object-top shadow-2xl"
                  src="https://github.com/user-attachments/assets/1850903a-5cc6-400d-8735-04634737ed6c"
                  alt="Runtime Headers settings screen"
                />
                <img
                  className="h-[207px] w-full rounded-md object-cover object-top shadow-2xl"
                  src="https://github.com/user-attachments/assets/e2ed8c22-0612-4d70-b284-ddac7bd0474b"
                  alt="Runtime Headers code appearance screen"
                />
              </div>
            </div>
          </div>
        </section>

        <Separator />

        <section id="screenshots" className="flex flex-col gap-5 pb-8">
          <div className="flex flex-col justify-between gap-3 md:flex-row md:items-end">
            <div className="flex flex-col gap-2">
              <h2 className="text-2xl font-semibold tracking-normal">Everything close at hand.</h2>
              <p className="max-w-2xl text-sm leading-6 text-muted-foreground">
                Inspection, history, settings, and saved references stay within a few taps.
              </p>
            </div>
            <Badge variant="secondary">Compact workflow</Badge>
          </div>
          <div className="-mx-5 overflow-x-auto px-5 pb-3 pt-1 md:-mx-8 md:px-8 no-scrollbar">
            <div className="flex w-max gap-4 pr-4">
              {screenshots.map((screenshot) => (
                <Card
                  key={screenshot.title}
                  className="w-[320px] overflow-hidden rounded-lg bg-card/80 md:w-90"
                >
                  <CardHeader>
                    <CardTitle>{screenshot.title}</CardTitle>
                    <CardDescription>Runtime Headers for iOS and iPadOS</CardDescription>
                  </CardHeader>
                  <CardContent>
                    <img
                      className="aspect-9/16 w-full rounded-md object-cover object-top"
                      src={screenshot.src}
                      alt={`${screenshot.title} screen`}
                    />
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        </section>
      </div>
    </main>
  )
}

export default App
