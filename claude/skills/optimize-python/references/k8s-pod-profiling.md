# Profiling Python in a Kubernetes Pod

Captures an austin/speedscope trace from a Python process running inside a
k8s pod, then retrieves the trace locally for analysis.

## Step 1: Find the Pod

Given something like "profile the foo service in the bar namespace":

```bash
kubectl get pods -n bar | grep foo
# or with label selectors:
kubectl get pods -n bar -l app=foo
kubectl get pods -n bar -l app.kubernetes.io/name=foo
```

Pick a running pod from the output.

## Step 2: Process Discovery

```bash
kubectl exec -n <namespace> <pod> -- ps aux | grep python
```

Find the PID of the target Python process. In many single-process pods,
it's PID 1.

## Step 3: Capture the Trace

Write to a file in the pod (recommended over stdout streaming; see Step 4):

```bash
kubectl exec -n <namespace> <pod> -- \
  austin -i 100 -o /tmp/austin.out -p <pid>
```

Add `-x <seconds>` to cap the capture duration; without it, austin runs
until the target process exits or you Ctrl-C.

Check the austin version to know which conversion steps are needed afterward:

```bash
kubectl exec -n <namespace> <pod> -- austin --version
```

## Step 4: Get the Trace Out of the Pod

**Do not use `kubectl exec` stdout streaming for binary data:** there are
[documented corruption issues](https://github.com/kubernetes/kubectl/issues/521)
in kubectl's output path. `kubectl cp` also has known
[timeout issues](https://github.com/kubernetes/kubernetes/issues/60140)
for larger files (it uses tar internally). Use the HTTP server method.

### Primary: Python HTTP server

The most reliable method. Python 3 is almost always present in Python pods.

```bash
# Start an HTTP server in the pod (backgrounds itself and returns)
kubectl exec -n <namespace> <pod> -- sh -c \
  'python3 -m http.server 8080 --directory /tmp &'
sleep 1

# Port-forward in the background, then download
kubectl port-forward -n <namespace> <pod> 8080:8080 &
PF_PID=$!
sleep 1
curl http://localhost:8080/austin.out -o austin.out

# Cleanup
kill "$PF_PID"
kubectl exec -n <namespace> <pod> -- pkill -f 'http.server'
```

If port 8080 is already in use in the pod, change it in both the server
command and the port-forward command.

### Backup: kubectl exec cat (collapsed text format only)

Works for collapsed text output (austin < 4). Not reliable for binary MOJO
format (austin >= 4), which suffers the same corruption issues as stdout
streaming.

```bash
kubectl exec -n <namespace> <pod> -- cat /tmp/austin.out > austin.out
```

## Step 5: Convert and Visualize

Follow the standard austin to speedscope pipeline from SKILL.md, using the
version-appropriate conversion for the format austin wrote (MOJO for >= 4,
collapsed text for < 4). Then analyze with `scripts/profile_speedscope.py`.

## Common Issues

- **austin binary missing**: Ask the user to add austin to the image build
  process (e.g. the Dockerfile). Do not install at runtime or copy in binaries.
- **Permission denied / ptrace error**: Pod lacks `SYS_PTRACE`. Ask the user
  to get the capability added to the pod's security context.
- **Port conflict**: Port 8080 already in use in the pod; try 8081 or
  another free port in both the server and port-forward commands.
- **MOJO conversion fails locally**: See the austin conversion pipeline in
  SKILL.md.
